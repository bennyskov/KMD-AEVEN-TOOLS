# (c) 2012-2014, Michael DeHaan <michael.dehaan@gmail.com>
# (c) 2021, Egor Margineanu <egor_margineanu@cz.ibm.com>
#
# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.
# Make coding more python3-ish
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible import constants as C
from ansible.playbook.task_include import TaskInclude
from ansible.utils.unsafe_proxy import wrap_var
from ansible.vars.clean import module_response_deepcopy, strip_internal_keys
from jinja2 import UndefinedError

DOCUMENTATION = '''
    strategy: kmn.utils.linear
    short_description: Executes tasks in a linear fashion
    description:
        - Task execution is in lockstep per host batch as defined by C(serial) (default all).
          Up to the fork limit of hosts will execute each task at the same time and then
          the next series of hosts until the batch is done, before going on to the next task.
          This correspond to linear strategy plugin in 2.9.15 and includes backport of 
          ansible/ansible#74290.
    version_added: "2.0"
    notes:
     - This was the default Ansible behaviour before 'strategy plugins' were introduced in 2.0.
    author: Ansible Core Team
'''

from ansible.errors import AnsibleError, AnsibleAssertionError, AnsibleUndefinedVariable
from ansible.executor.play_iterator import PlayIterator
from ansible.module_utils.six import iteritems
from ansible.module_utils._text import to_text
from ansible.playbook.block import Block
from ansible.playbook.included_file import IncludedFile
from ansible.playbook.task import Task
from ansible.plugins.loader import action_loader
from ansible.plugins.strategy import StrategyBase, debug_closure
from ansible.template import Templar
from ansible.utils.display import Display

display = Display()


class StrategyModule(StrategyBase):

    noop_task = None

    def _replace_with_noop(self, target):
        if self.noop_task is None:
            raise AnsibleAssertionError('strategy.linear.StrategyModule.noop_task is None, need Task()')

        result = []
        for el in target:
            if isinstance(el, Task):
                result.append(self.noop_task)
            elif isinstance(el, Block):
                result.append(self._create_noop_block_from(el, el._parent))
        return result

    def _create_noop_block_from(self, original_block, parent):
        noop_block = Block(parent_block=parent)
        noop_block.block = self._replace_with_noop(original_block.block)
        noop_block.always = self._replace_with_noop(original_block.always)
        noop_block.rescue = self._replace_with_noop(original_block.rescue)

        return noop_block

    def _prepare_and_create_noop_block_from(self, original_block, parent, iterator):
        self.noop_task = Task()
        self.noop_task.action = 'meta'
        self.noop_task.args['_raw_params'] = 'noop'
        self.noop_task.set_loader(iterator._play._loader)

        return self._create_noop_block_from(original_block, parent)

    def _get_next_task_lockstep(self, hosts, iterator):
        '''
        Returns a list of (host, task) tuples, where the task may
        be a noop task to keep the iterator in lock step across
        all hosts.
        '''

        noop_task = Task()
        noop_task.action = 'meta'
        noop_task.args['_raw_params'] = 'noop'
        noop_task.set_loader(iterator._play._loader)

        host_tasks = {}
        display.debug("building list of next tasks for hosts")
        for host in hosts:
            host_tasks[host.name] = iterator.get_next_task_for_host(host, peek=True)
        display.debug("done building task lists")

        num_setups = 0
        num_tasks = 0
        num_rescue = 0
        num_always = 0

        display.debug("counting tasks in each state of execution")
        host_tasks_to_run = [(host, state_task)
                             for host, state_task in iteritems(host_tasks)
                             if state_task and state_task[1]]

        if host_tasks_to_run:
            try:
                lowest_cur_block = min(
                    (iterator.get_active_state(s).cur_block for h, (s, t) in host_tasks_to_run
                     if s.run_state != PlayIterator.ITERATING_COMPLETE))
            except ValueError:
                lowest_cur_block = None
        else:
            # empty host_tasks_to_run will just run till the end of the function
            # without ever touching lowest_cur_block
            lowest_cur_block = None

        for (k, v) in host_tasks_to_run:
            (s, t) = v

            s = iterator.get_active_state(s)
            if s.cur_block > lowest_cur_block:
                # Not the current block, ignore it
                continue

            if s.run_state == PlayIterator.ITERATING_SETUP:
                num_setups += 1
            elif s.run_state == PlayIterator.ITERATING_TASKS:
                num_tasks += 1
            elif s.run_state == PlayIterator.ITERATING_RESCUE:
                num_rescue += 1
            elif s.run_state == PlayIterator.ITERATING_ALWAYS:
                num_always += 1
        display.debug("done counting tasks in each state of execution:\n\tnum_setups: %s\n\tnum_tasks: %s\n\tnum_rescue: %s\n\tnum_always: %s" % (num_setups,
                                                                                                                                                  num_tasks,
                                                                                                                                                  num_rescue,
                                                                                                                                                  num_always))

        def _advance_selected_hosts(hosts, cur_block, cur_state):
            '''
            This helper returns the task for all hosts in the requested
            state, otherwise they get a noop dummy task. This also advances
            the state of the host, since the given states are determined
            while using peek=True.
            '''
            # we return the values in the order they were originally
            # specified in the given hosts array
            rvals = []
            display.debug("starting to advance hosts")
            for host in hosts:
                host_state_task = host_tasks.get(host.name)
                if host_state_task is None:
                    continue
                (s, t) = host_state_task
                s = iterator.get_active_state(s)
                if t is None:
                    continue
                if s.run_state == cur_state and s.cur_block == cur_block:
                    new_t = iterator.get_next_task_for_host(host)
                    rvals.append((host, t))
                else:
                    rvals.append((host, noop_task))
            display.debug("done advancing hosts to next task")
            return rvals

        # if any hosts are in ITERATING_SETUP, return the setup task
        # while all other hosts get a noop
        if num_setups:
            display.debug("advancing hosts in ITERATING_SETUP")
            return _advance_selected_hosts(hosts, lowest_cur_block, PlayIterator.ITERATING_SETUP)

        # if any hosts are in ITERATING_TASKS, return the next normal
        # task for these hosts, while all other hosts get a noop
        if num_tasks:
            display.debug("advancing hosts in ITERATING_TASKS")
            return _advance_selected_hosts(hosts, lowest_cur_block, PlayIterator.ITERATING_TASKS)

        # if any hosts are in ITERATING_RESCUE, return the next rescue
        # task for these hosts, while all other hosts get a noop
        if num_rescue:
            display.debug("advancing hosts in ITERATING_RESCUE")
            return _advance_selected_hosts(hosts, lowest_cur_block, PlayIterator.ITERATING_RESCUE)

        # if any hosts are in ITERATING_ALWAYS, return the next always
        # task for these hosts, while all other hosts get a noop
        if num_always:
            display.debug("advancing hosts in ITERATING_ALWAYS")
            return _advance_selected_hosts(hosts, lowest_cur_block, PlayIterator.ITERATING_ALWAYS)

        # at this point, everything must be ITERATING_COMPLETE, so we
        # return None for all hosts in the list
        display.debug("all hosts are done, so returning None's for all hosts")
        return [(host, None) for host in hosts]

    def run(self, iterator, play_context):
        '''
        The linear strategy is simple - get the next task and queue
        it for all hosts, then wait for the queue to drain before
        moving on to the next task
        '''

        # iterate over each task, while there is one left to run
        result = self._tqm.RUN_OK
        work_to_do = True

        self._set_hosts_cache(iterator._play)

        while work_to_do and not self._tqm._terminated:

            try:
                display.debug("getting the remaining hosts for this loop")
                hosts_left = self.get_hosts_left(iterator)
                display.debug("done getting the remaining hosts for this loop")

                # queue up this task for each host in the inventory
                callback_sent = False
                work_to_do = False

                host_results = []
                host_tasks = self._get_next_task_lockstep(hosts_left, iterator)

                # skip control
                skip_rest = False
                choose_step = True

                # flag set if task is set to any_errors_fatal
                any_errors_fatal = False

                results = []
                for (host, task) in host_tasks:
                    if not task:
                        continue

                    if self._tqm._terminated:
                        break

                    run_once = False
                    work_to_do = True

                    # test to see if the task across all hosts points to an action plugin which
                    # sets BYPASS_HOST_LOOP to true, or if it has run_once enabled. If so, we
                    # will only send this task to the first host in the list.

                    try:
                        action = action_loader.get(task.action, class_only=True)
                    except KeyError:
                        # we don't care here, because the action may simply not have a
                        # corresponding action plugin
                        action = None

                    # check to see if this task should be skipped, due to it being a member of a
                    # role which has already run (and whether that role allows duplicate execution)
                    if task._role and task._role.has_run(host):
                        # If there is no metadata, the default behavior is to not allow duplicates,
                        # if there is metadata, check to see if the allow_duplicates flag was set to true
                        if task._role._metadata is None or task._role._metadata and not task._role._metadata.allow_duplicates:
                            display.debug("'%s' skipped because role has already run" % task)
                            continue

                    if task.action == 'meta':
                        # for the linear strategy, we run meta tasks just once and for
                        # all hosts currently being iterated over rather than one host
                        results.extend(self._execute_meta(task, play_context, iterator, host))
                        if task.args.get('_raw_params', None) not in ('noop', 'reset_connection', 'end_host'):
                            run_once = True
                        if (task.any_errors_fatal or run_once) and not task.ignore_errors:
                            any_errors_fatal = True
                    else:
                        # handle step if needed, skip meta actions as they are used internally
                        if self._step and choose_step:
                            if self._take_step(task):
                                choose_step = False
                            else:
                                skip_rest = True
                                break

                        display.debug("getting variables")
                        task_vars = self._variable_manager.get_vars(play=iterator._play, host=host, task=task,
                                                                    _hosts=self._hosts_cache, _hosts_all=self._hosts_cache_all)
                        self.add_tqm_variables(task_vars, play=iterator._play)
                        templar = Templar(loader=self._loader, variables=task_vars)
                        display.debug("done getting variables")

                        run_once = templar.template(task.run_once) or action and getattr(action, 'BYPASS_HOST_LOOP', False)

                        if (task.any_errors_fatal or run_once) and not task.ignore_errors:
                            any_errors_fatal = True

                        if not callback_sent:
                            display.debug("sending task start callback, copying the task so we can template it temporarily")
                            saved_name = task.name
                            display.debug("done copying, going to template now")
                            try:
                                task.name = to_text(templar.template(task.name, fail_on_undefined=False), nonstring='empty')
                                display.debug("done templating")
                            except Exception:
                                # just ignore any errors during task name templating,
                                # we don't care if it just shows the raw name
                                display.debug("templating failed for some reason")
                            display.debug("here goes the callback...")
                            self._tqm.send_callback('v2_playbook_on_task_start', task, is_conditional=False)
                            task.name = saved_name
                            callback_sent = True
                            display.debug("sending task start callback")

                        self._blocked_hosts[host.get_name()] = True
                        self._queue_task(host, task, task_vars, play_context)
                        del task_vars

                    # if we're bypassing the host loop, break out now
                    if run_once:
                        break

                    results += self._process_pending_results(iterator, max_passes=max(1, int(len(self._tqm._workers) * 0.1)))

                # go to next host/task group
                if skip_rest:
                    continue

                display.debug("done queuing things up, now waiting for results queue to drain")
                if self._pending_results > 0:
                    results += self._wait_on_pending_results(iterator)

                host_results.extend(results)

                self.update_active_connections(results)

                included_files = IncludedFile.process_include_results(
                    host_results,
                    iterator=iterator,
                    loader=self._loader,
                    variable_manager=self._variable_manager
                )

                include_failure = False
                if len(included_files) > 0:
                    display.debug("we have included files to process")

                    display.debug("generating all_blocks data")
                    all_blocks = dict((host, []) for host in hosts_left)
                    display.debug("done generating all_blocks data")
                    for included_file in included_files:
                        display.debug("processing included file: %s" % included_file._filename)
                        # included hosts get the task list while those excluded get an equal-length
                        # list of noop tasks, to make sure that they continue running in lock-step
                        try:
                            if included_file._is_role:
                                new_ir = self._copy_included_file(included_file)

                                new_blocks, handler_blocks = new_ir.get_block_list(
                                    play=iterator._play,
                                    variable_manager=self._variable_manager,
                                    loader=self._loader,
                                )
                            else:
                                new_blocks = self._load_included_file(included_file, iterator=iterator)

                            display.debug("iterating over new_blocks loaded from include file")
                            for new_block in new_blocks:
                                task_vars = self._variable_manager.get_vars(
                                    play=iterator._play,
                                    task=new_block._parent,
                                    _hosts=self._hosts_cache,
                                    _hosts_all=self._hosts_cache_all,
                                )
                                display.debug("filtering new block on tags")
                                final_block = new_block.filter_tagged_tasks(task_vars)
                                display.debug("done filtering new block on tags")

                                noop_block = self._prepare_and_create_noop_block_from(final_block, task._parent, iterator)

                                for host in hosts_left:
                                    if host in included_file._hosts:
                                        all_blocks[host].append(final_block)
                                    else:
                                        all_blocks[host].append(noop_block)
                            display.debug("done iterating over new_blocks loaded from include file")

                        except AnsibleError as e:
                            for host in included_file._hosts:
                                self._tqm._failed_hosts[host.name] = True
                                iterator.mark_host_failed(host)
                            display.error(to_text(e), wrap_text=False)
                            include_failure = True
                            continue

                    # finally go through all of the hosts and append the
                    # accumulated blocks to their list of tasks
                    display.debug("extending task lists for all hosts with included blocks")

                    for host in hosts_left:
                        iterator.add_tasks(host, all_blocks[host])

                    display.debug("done extending task lists")
                    display.debug("done processing included files")

                display.debug("results queue empty")

                display.debug("checking for any_errors_fatal")
                failed_hosts = []
                unreachable_hosts = []
                for res in results:
                    # execute_meta() does not set 'failed' in the TaskResult
                    # so we skip checking it with the meta tasks and look just at the iterator
                    if (res.is_failed() or res._task.action == 'meta') and iterator.is_failed(res._host):
                        failed_hosts.append(res._host.name)
                    elif res.is_unreachable():
                        unreachable_hosts.append(res._host.name)

                # if any_errors_fatal and we had an error, mark all hosts as failed
                if any_errors_fatal and (len(failed_hosts) > 0 or len(unreachable_hosts) > 0):
                    dont_fail_states = frozenset([iterator.ITERATING_RESCUE, iterator.ITERATING_ALWAYS])
                    for host in hosts_left:
                        (s, _) = iterator.get_next_task_for_host(host, peek=True)
                        # the state may actually be in a child state, use the get_active_state()
                        # method in the iterator to figure out the true active state
                        s = iterator.get_active_state(s)
                        if s.run_state not in dont_fail_states or \
                           s.run_state == iterator.ITERATING_RESCUE and s.fail_state & iterator.FAILED_RESCUE != 0:
                            self._tqm._failed_hosts[host.name] = True
                            result |= self._tqm.RUN_FAILED_BREAK_PLAY
                display.debug("done checking for any_errors_fatal")

                display.debug("checking for max_fail_percentage")
                if iterator._play.max_fail_percentage is not None and len(results) > 0:
                    percentage = iterator._play.max_fail_percentage / 100.0

                    if (len(self._tqm._failed_hosts) / iterator.batch_size) > percentage:
                        for host in hosts_left:
                            # don't double-mark hosts, or the iterator will potentially
                            # fail them out of the rescue/always states
                            if host.name not in failed_hosts:
                                self._tqm._failed_hosts[host.name] = True
                                iterator.mark_host_failed(host)
                        self._tqm.send_callback('v2_playbook_on_no_hosts_remaining')
                        result |= self._tqm.RUN_FAILED_BREAK_PLAY
                    display.debug('(%s failed / %s total )> %s max fail' % (len(self._tqm._failed_hosts), iterator.batch_size, percentage))
                display.debug("done checking for max_fail_percentage")

                display.debug("checking to see if all hosts have failed and the running result is not ok")
                if result != self._tqm.RUN_OK and len(self._tqm._failed_hosts) >= len(hosts_left):
                    display.debug("^ not ok, so returning result now")
                    self._tqm.send_callback('v2_playbook_on_no_hosts_remaining')
                    return result
                display.debug("done checking to see if all hosts have failed")

            except (IOError, EOFError) as e:
                display.debug("got IOError/EOFError in task loop: %s" % e)
                # most likely an abort, return failed
                return self._tqm.RUN_UNKNOWN_ERROR

        # run the base class run() method, which executes the cleanup function
        # and runs any outstanding handlers which have been triggered

        return super(StrategyModule, self).run(iterator, play_context, result)

    @debug_closure
    def _process_pending_results(self, iterator, one_pass=False, max_passes=None, do_handlers=False):
        '''
        Reads results off the final queue and takes appropriate action
        based on the result (executing callbacks, updating state, etc.).
        '''

        ret_results = []
        handler_templar = Templar(self._loader)

        def get_original_host(host_name):
            # FIXME: this should not need x2 _inventory
            host_name = to_text(host_name)
            if host_name in self._inventory.hosts:
                return self._inventory.hosts[host_name]
            else:
                return self._inventory.get_host(host_name)

        def search_handler_blocks_by_name(handler_name, handler_blocks):
            # iterate in reversed order since last handler loaded with the same name wins
            for handler_block in reversed(handler_blocks):
                for handler_task in handler_block.block:
                    if handler_task.name:
                        if not handler_task.cached_name:
                            if handler_templar.is_template(handler_task.name):
                                handler_templar.available_variables = self._variable_manager.get_vars(play=iterator._play,
                                                                                                      task=handler_task,
                                                                                                      _hosts=self._hosts_cache,
                                                                                                      _hosts_all=self._hosts_cache_all)
                                handler_task.name = handler_templar.template(handler_task.name)
                            handler_task.cached_name = True

                        try:
                            # first we check with the full result of get_name(), which may
                            # include the role name (if the handler is from a role). If that
                            # is not found, we resort to the simple name field, which doesn't
                            # have anything extra added to it.
                            candidates = (
                                handler_task.name,
                                handler_task.get_name(include_role_fqcn=False),
                                handler_task.get_name(include_role_fqcn=True),
                            )

                            if handler_name in candidates:
                                return handler_task
                        except (UndefinedError, AnsibleUndefinedVariable):
                            # We skip this handler due to the fact that it may be using
                            # a variable in the name that was conditionally included via
                            # set_fact or some other method, and we don't want to error
                            # out unnecessarily
                            continue
            return None

        cur_pass = 0
        while True:
            try:
                self._results_lock.acquire()
                if do_handlers:
                    task_result = self._handler_results.popleft()
                else:
                    task_result = self._results.popleft()
            except IndexError:
                break
            finally:
                self._results_lock.release()

            # get the original host and task. We then assign them to the TaskResult for use in callbacks/etc.
            original_host = get_original_host(task_result._host)
            queue_cache_entry = (original_host.name, task_result._task)
            found_task = self._queued_task_cache.get(queue_cache_entry)['task']
            original_task = found_task.copy(exclude_parent=True, exclude_tasks=True)
            original_task._parent = found_task._parent
            original_task.from_attrs(task_result._task_fields)

            task_result._host = original_host
            task_result._task = original_task

            # send callbacks for 'non final' results
            if '_ansible_retry' in task_result._result:
                self._tqm.send_callback('v2_runner_retry', task_result)
                continue
            elif '_ansible_item_result' in task_result._result:
                if task_result.is_failed() or task_result.is_unreachable():
                    self._tqm.send_callback('v2_runner_item_on_failed', task_result)
                elif task_result.is_skipped():
                    self._tqm.send_callback('v2_runner_item_on_skipped', task_result)
                else:
                    if 'diff' in task_result._result:
                        if self._diff or getattr(original_task, 'diff', False):
                            self._tqm.send_callback('v2_on_file_diff', task_result)
                    self._tqm.send_callback('v2_runner_item_on_ok', task_result)
                continue

            if original_task.register:
                host_list = self.get_task_hosts(iterator, original_host, original_task)

                clean_copy = strip_internal_keys(module_response_deepcopy(task_result._result))
                if 'invocation' in clean_copy:
                    del clean_copy['invocation']

                for target_host in host_list:
                    self._variable_manager.set_nonpersistent_facts(target_host, {original_task.register: clean_copy})

            # all host status messages contain 2 entries: (msg, task_result)
            role_ran = False
            if task_result.is_failed():
                role_ran = True
                ignore_errors = original_task.ignore_errors
                if not ignore_errors:
                    display.debug("marking %s as failed" % original_host.name)
                    if original_task.run_once:
                        # if we're using run_once, we have to fail every host here
                        for h in self._inventory.get_hosts(iterator._play.hosts):
                            if h.name not in self._tqm._unreachable_hosts:
                                state, _ = iterator.get_next_task_for_host(h, peek=True)
                                iterator.mark_host_failed(h)
                                state, new_task = iterator.get_next_task_for_host(h, peek=True)
                    else:
                        iterator.mark_host_failed(original_host)

                    # grab the current state and if we're iterating on the rescue portion
                    # of a block then we save the failed task in a special var for use
                    # within the rescue/always
                    state, _ = iterator.get_next_task_for_host(original_host, peek=True)

                    if iterator.is_failed(original_host) and state and state.run_state == iterator.ITERATING_COMPLETE:
                        self._tqm._failed_hosts[original_host.name] = True

                    if state and iterator.get_active_state(state).run_state == iterator.ITERATING_RESCUE:
                        self._tqm._stats.increment('rescued', original_host.name)
                        self._variable_manager.set_nonpersistent_facts(
                            original_host.name,
                            dict(
                                ansible_failed_task=wrap_var(original_task.serialize()),
                                ansible_failed_result=task_result._result,
                            ),
                        )
                    else:
                        self._tqm._stats.increment('failures', original_host.name)
                else:
                    self._tqm._stats.increment('ok', original_host.name)
                    self._tqm._stats.increment('ignored', original_host.name)
                    if 'changed' in task_result._result and task_result._result['changed']:
                        self._tqm._stats.increment('changed', original_host.name)
                self._tqm.send_callback('v2_runner_on_failed', task_result, ignore_errors=ignore_errors)
            elif task_result.is_unreachable():
                ignore_unreachable = original_task.ignore_unreachable
                if not ignore_unreachable:
                    self._tqm._unreachable_hosts[original_host.name] = True
                    iterator._play._removed_hosts.append(original_host.name)
                else:
                    self._tqm._stats.increment('skipped', original_host.name)
                    task_result._result['skip_reason'] = 'Host %s is unreachable' % original_host.name
                self._tqm._stats.increment('dark', original_host.name)
                self._tqm.send_callback('v2_runner_on_unreachable', task_result)
            elif task_result.is_skipped():
                self._tqm._stats.increment('skipped', original_host.name)
                self._tqm.send_callback('v2_runner_on_skipped', task_result)
            else:
                role_ran = True

                if original_task.loop:
                    # this task had a loop, and has more than one result, so
                    # loop over all of them instead of a single result
                    result_items = task_result._result.get('results', [])
                else:
                    result_items = [task_result._result]

                for result_item in result_items:
                    if '_ansible_notify' in result_item:
                        if task_result.is_changed():
                            # The shared dictionary for notified handlers is a proxy, which
                            # does not detect when sub-objects within the proxy are modified.
                            # So, per the docs, we reassign the list so the proxy picks up and
                            # notifies all other threads
                            for handler_name in result_item['_ansible_notify']:
                                found = False
                                # Find the handler using the above helper.  First we look up the
                                # dependency chain of the current task (if it's from a role), otherwise
                                # we just look through the list of handlers in the current play/all
                                # roles and use the first one that matches the notify name
                                target_handler = search_handler_blocks_by_name(handler_name, iterator._play.handlers)
                                if target_handler is not None:
                                    found = True
                                    if target_handler.notify_host(original_host):
                                        self._tqm.send_callback('v2_playbook_on_notify', target_handler, original_host)

                                for listening_handler_block in iterator._play.handlers:
                                    for listening_handler in listening_handler_block.block:
                                        listeners = getattr(listening_handler, 'listen', []) or []
                                        if not listeners:
                                            continue

                                        listeners = listening_handler.get_validated_value(
                                            'listen', listening_handler._valid_attrs['listen'], listeners, handler_templar
                                        )
                                        if handler_name not in listeners:
                                            continue
                                        else:
                                            found = True

                                        if listening_handler.notify_host(original_host):
                                            self._tqm.send_callback('v2_playbook_on_notify', listening_handler, original_host)

                                # and if none were found, then we raise an error
                                if not found:
                                    msg = ("The requested handler '%s' was not found in either the main handlers list nor in the listening "
                                           "handlers list" % handler_name)
                                    if C.ERROR_ON_MISSING_HANDLER:
                                        raise AnsibleError(msg)
                                    else:
                                        display.warning(msg)

                    if 'add_host' in result_item:
                        # this task added a new host (add_host module)
                        new_host_info = result_item.get('add_host', dict())
                        self._add_host(new_host_info, iterator)

                    elif 'add_group' in result_item:
                        # this task added a new group (group_by module)
                        self._add_group(original_host, result_item)

                    if 'ansible_facts' in result_item:
                        # if delegated fact and we are delegating facts, we need to change target host for them
                        if original_task.delegate_to is not None and original_task.delegate_facts:
                            host_list = self.get_delegated_hosts(result_item, original_task)
                        else:
                            # Set facts that should always be on the delegated hosts
                            self._set_always_delegated_facts(result_item, original_task)

                            host_list = self.get_task_hosts(iterator, original_host, original_task)

                        if original_task.action == 'include_vars':
                            for (var_name, var_value) in iteritems(result_item['ansible_facts']):
                                # find the host we're actually referring too here, which may
                                # be a host that is not really in inventory at all
                                for target_host in host_list:
                                    self._variable_manager.set_host_variable(target_host, var_name, var_value)
                        else:
                            cacheable = result_item.pop('_ansible_facts_cacheable', False)
                            for target_host in host_list:
                                # so set_fact is a misnomer but 'cacheable = true' was meant to create an 'actual fact'
                                # to avoid issues with precedence and confusion with set_fact normal operation,
                                # we set BOTH fact and nonpersistent_facts (aka hostvar)
                                # when fact is retrieved from cache in subsequent operations it will have the lower precedence,
                                # but for playbook setting it the 'higher' precedence is kept
                                if original_task.action != 'set_fact' or cacheable:
                                    self._variable_manager.set_host_facts(target_host, result_item['ansible_facts'].copy())
                                if original_task.action == 'set_fact':
                                    self._variable_manager.set_nonpersistent_facts(target_host, result_item['ansible_facts'].copy())

                    if 'ansible_stats' in result_item and 'data' in result_item['ansible_stats'] and result_item['ansible_stats']['data']:

                        if 'per_host' not in result_item['ansible_stats'] or result_item['ansible_stats']['per_host']:
                            host_list = self.get_task_hosts(iterator, original_host, original_task)
                        else:
                            host_list = [None]

                        data = result_item['ansible_stats']['data']
                        aggregate = 'aggregate' in result_item['ansible_stats'] and result_item['ansible_stats']['aggregate']
                        for myhost in host_list:
                            for k in data.keys():
                                if aggregate:
                                    self._tqm._stats.update_custom_stats(k, data[k], myhost)
                                else:
                                    self._tqm._stats.set_custom_stats(k, data[k], myhost)

                if 'diff' in task_result._result:
                    if self._diff or getattr(original_task, 'diff', False):
                        self._tqm.send_callback('v2_on_file_diff', task_result)

                if not isinstance(original_task, TaskInclude):
                    self._tqm._stats.increment('ok', original_host.name)
                    if 'changed' in task_result._result and task_result._result['changed']:
                        self._tqm._stats.increment('changed', original_host.name)

                # finally, send the ok for this task
                self._tqm.send_callback('v2_runner_on_ok', task_result)

            if do_handlers:
                self._pending_handler_results -= 1
            else:
                self._pending_results -= 1
            if original_host.name in self._blocked_hosts:
                del self._blocked_hosts[original_host.name]

            # If this is a role task, mark the parent role as being run (if
            # the task was ok or failed, but not skipped or unreachable)
            if original_task._role is not None and role_ran:  # TODO:  and original_task.action != 'include_role':?
                # lookup the role in the ROLE_CACHE to make sure we're dealing
                # with the correct object and mark it as executed
                for (entry, role_obj) in iteritems(iterator._play.ROLE_CACHE[original_task._role.get_name()]):
                    if role_obj._uuid == original_task._role._uuid:
                        role_obj._had_task_run[original_host.name] = True

            ret_results.append(task_result)

            if one_pass or max_passes is not None and (cur_pass + 1) >= max_passes:
                break

            cur_pass += 1

        return ret_results
