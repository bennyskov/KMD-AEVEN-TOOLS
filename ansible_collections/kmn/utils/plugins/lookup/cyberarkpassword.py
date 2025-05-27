# (c) 2017, Edward Nunez <edward.nunez@cyberark.com>
# (c) 2017 Ansible Project
# (c) 2020,2021 IBM
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
from __future__ import (absolute_import, division, print_function)

__metaclass__ = type
DOCUMENTATION = """
    lookup: cyberarkpassword
    version_added: "2.9"
    short_description: Retrieves secrets from CyberArk AIM using WebService API
    description:
        - Retrieves secrets from CyberArk AIM using WebService API
    options :
        app_id:
            description: Defines the unique ID of the application that is issuing the secret request
            required: True
        query:
            description: Describes the filter criteria for the password retrieval
            required: True
        object_query_format:
            description: Defines for of object query
            default: 'Regexp'
        url:
            description: Defines CyberArk endpoint URL
            required: True 
"""
EXAMPLES = """
    - name: passing options to the lookup
      debug: 
          msg={{ lookup("kmn.utils.cyberarkpassword", cyquery)}}
      vars:
          cyquery:
              app_id: "app_ansible"
              query: "object=^pimadm_win_te_{{ inventory_hostname }}$"
              object_query_format: "Regexp"
              url: "https://kmdwinccp001.adminkmd.local/"
"""
RETURN = """
  secret:
    description:
      - The actual value stored in CyberArk
"""
from ansible.errors import AnsibleError
from ansible.plugins.lookup import LookupBase
from ansible.utils.display import Display
from ansible.module_utils.six.moves.urllib.error import HTTPError, URLError
from ansible.module_utils.six.moves.urllib.parse import urlencode, urljoin
from ansible.module_utils._text import to_native
from ansible.module_utils.urls import open_url, ConnectionError, SSLValidationError
import os
import stat

display = Display()


class CyberarkPassword:
    def __init__(self, url=None, app_id=None, query=None, object_query_format="Exact", output=None):
        self.url = url
        self.app_id = app_id
        self.query = query
        self.output = output
        self.object_query_format = object_query_format

    def get(self):
        query_params = {
            'AppId': self.app_id,
            'Query': self.query,
            'QueryFormat': self.object_query_format,
        }
        request_qs = '?' + urlencode(query_params)
        request_url = urljoin(self.url, '/'.join(['AIMWebService', 'api', 'Accounts']))

        try:
            res = open_url(
                request_url + request_qs,
                timeout=60,
                validate_certs=False
            )
        except HTTPError as e:
            raise AnsibleError("Received HTTP error for %s : %s" % (self.query, to_native(e)))
        except URLError as e:
            raise AnsibleError("Failed lookup url for %s : %s" % (self.query, to_native(e)))
        except SSLValidationError as e:
            raise AnsibleError("Error validating the server's certificate for %s: %s" % (self.query, to_native(e)))
        except ConnectionError as e:
            raise AnsibleError("Error connecting to %s: %s" % (self.query, to_native(e)))

        if len(res.json()['Content']) > 50:
            pid = os.getpid()
            homedir = os.getenv('ANSIBLE_SSH_CONTROL_PATH_DIR')
            fn = homedir + "/../" + 'key' + str(pid) + '.tmp'
            #            print(fn)
            f = open(fn, 'w')
            f.write(res.json()['Content'])
            f.close()
            os.chmod(fn, stat.S_IRUSR | stat.S_IWUSR)
            return fn
        else:
            return res.json()['Content']


class LookupModule(LookupBase):

    def run(self, terms, variables=None, **kwargs):

        display.vvvv("%s" % terms)

        if isinstance(terms, list):
            return_values = []
            for term in terms:
                display.vvvv("Term: %s" % term)
                cyberark_conn = CyberarkPassword(**term)
                return_values.append(cyberark_conn.get())
            return return_values
        else:
            cyberark_conn = CyberarkPassword(**terms)
            result = cyberark_conn.get()
            return result
