# Windows Verification Playbook Redesign Analysis

## Project Objective
Redesign the `de-tooling_verify_windows.yml` playbook to automatically detect and assign correct inventory and credentials for Windows server verification across 4 customer inventories, eliminating hard failures when hosts are not found in the current inventory.

## Problem Statement
The original playbook fails hard when a host (e.g., `eboksweb2302`) is not found in the current inventory, requiring manual intervention to determine the correct inventory and credentials. This creates operational inefficiency and blocks automation workflows.

## Current State Analysis

### Original Playbook Issues
1. **Hard Failure Behavior**: Playbook terminates when host not found in current inventory
2. **Manual Inventory Selection**: Requires operators to know which inventory contains the target host
3. **Static Credential Assignment**: Uses hardcoded credentials based on inventory
4. **No Cross-Inventory Search**: Cannot discover hosts in other customer inventories

### Customer Environment Complexity
- **4 Customer Inventories**: `kmn_inventory`, `kmw_inventory`, `eng_inventory`, `eng_hem`
- **No Standardized Naming**: Hosts from different customers have unique naming patterns
- **Dynamic Credentials**: Credentials are stored as group variables, not predictable patterns
- **Multi-Organization**: Each inventory represents different customer organizations

## Research and Analysis Completed

### 1. Error Log Analysis
- Analyzed job logs from failed executions (job_246955*.txt)
- Identified pattern: Host `eboksweb2302` exists but not in current inventory
- Confirmed need for cross-inventory search capability

### 2. Proven Pattern Discovery
**Key Finding**: The `launch_and_misc_awx_functions.py` script (lines 530-580, 680-720) contains a proven pattern that successfully handles this exact scenario.

#### Python Script Pattern (Lines 530-580):
```python
# Global host search across all inventories
acceptedInv = ['kmn_inventory','kmw_inventory','eng_inventory','eng_hem']
checkCaps = [f'{nodename.lower()}',f'{nodename.upper()}']

for capsOrNot in checkCaps:
    request = f'hosts/?name={capsOrNot}'
    result,RC = f_requests(request,twusr,twpwd,payload,debug)

    for row in datalist:
        checkName = row['summary_fields']['inventory']['name']
        if checkName in acceptedInv:
            # Found host in accepted inventory
            inventory_id = row['summary_fields']['inventory']['id']
            host_id = row['id']
            nodename = row['name']
```

#### Credential Discovery Pattern (Lines 680-720):
```python
# Get all groups for the host
request = f'hosts/{host_id}/all_groups/?page_size=all'
allGroupsWithHost = result['results']

# Extract credentials from group variables
for group in allGroupsWithHost:
    if group['variables']:
        variables_dict = yaml.safe_load(group['variables'])
        os_cred = variables_dict.get('os_credential')
        jumphost_cred = variables_dict.get('jumphost_credential')
```

### 3. Organization Mapping Analysis
Established correct customer organization mappings:
- **KMN**: `kmn_inventory` (KMD Maintenance Network)
- **KMW**: `kmw_inventory` (KMD West/Workplace)
- **Energinet**: `eng_inventory` (Danish energy transmission)
- **HEM**: `eng_hem` (HEM subsidiary under Energinet)

## Recommended Solution Architecture

### Core Design Principles
1. **Follow Proven Pattern**: Use the exact API pattern from `launch_and_misc_awx_functions.py`
2. **Global Host Search**: Single API call to search all inventories
3. **Group-Based Credentials**: Extract credentials from group variables, not hostname patterns
4. **Graceful Error Handling**: Provide helpful guidance when hosts aren't found
5. **Backward Compatibility**: Support both single-host and inventory-wide execution

### Proposed Playbook Structure

#### Play 1: Host Discovery and Credential Resolution
```yaml
- name: Pre-flight validation and inventory detection
  hosts: localhost
  gather_facts: false
  vars:
    accepted_inventories: ['kmn_inventory', 'kmw_inventory', 'eng_inventory', 'eng_hem']

  tasks:
    # 1. Determine execution mode (single host vs inventory-wide)
    # 2. Check if host exists in current inventory
    # 3. If not found locally, perform global search
    # 4. Filter results by accepted inventories
    # 5. Get host groups and extract credentials from group variables
    # 6. Set execution variables for main verification play
```

#### Play 2: Windows Verification
```yaml
- name: Windows Server Verification with Dynamic Credentials
  hosts: "{{ target_host if single_host_mode else 'all' }}"
  gather_facts: true

  tasks:
    # 1. Display discovered credentials and context
    # 2. Perform comprehensive Windows verification
    # 3. Generate detailed system report
```

### Key Implementation Details

#### 1. Global Host Search API Pattern
```yaml
- name: Global host search (following Python script pattern)
  uri:
    url: "{{ tower_host }}/api/v2/hosts/?name={{ nodename | lower }}"
    method: GET
    headers:
      Authorization: "Bearer {{ tower_token }}"
  register: global_search_result

- name: Filter by accepted customer inventories
  set_fact:
    found_hosts: "{{ global_search_result.json.results |
                    selectattr('summary_fields.inventory.name', 'in', accepted_inventories) |
                    list }}"
```

#### 2. Group-Based Credential Discovery
```yaml
- name: Get host groups for credential discovery
  uri:
    url: "{{ tower_host }}/api/v2/hosts/{{ target_host_id }}/all_groups/"
    method: GET
    headers:
      Authorization: "Bearer {{ tower_token }}"
  register: host_groups_result

- name: Extract credentials from group variables
  # Loop through groups and extract os_credential and jumphost_credential
  # from YAML variables in each group
```

#### 3. Enhanced Error Handling
```yaml
- name: Handle host not found scenario
  debug:
    msg: |
      ❌ HOST NOT FOUND ERROR:
      Host '{{ nodename }}' was not found in any accepted customer inventory.

      Recommendations:
      1. Check hostname spelling and casing
      2. Verify host exists in Tower/AWX web interface
      3. Contact the team managing the target environment
```

## Implementation Challenges Encountered

### 1. YAML Syntax Issues
- **Problem**: Complex nested structures caused YAML parsing errors
- **Solution**: Use simpler task structures and proper indentation
- **Lesson**: Test YAML syntax incrementally, avoid complex inline structures

### 2. Ansible include_tasks Limitations
- **Problem**: Attempted to use `include_tasks` with inline task definitions
- **Solution**: Use direct loops with `uri` module calls
- **Lesson**: Ansible requires explicit task files for `include_tasks`

### 3. Variable Scope Complexity
- **Problem**: Passing discovered credentials between plays
- **Solution**: Use `hostvars['localhost']` pattern for cross-play variable access
- **Lesson**: Plan variable scope carefully in multi-play playbooks

## Testing Strategy

### 1. Test Cases
1. **Happy Path**: Host exists in current inventory
2. **Cross-Inventory**: Host exists in different accepted inventory (`eboksweb2302` scenario)
3. **Not Found**: Host doesn't exist in any accepted inventory
4. **Multiple Matches**: Host exists in multiple inventories
5. **Inventory-Wide**: Execute against all hosts in current inventory

### 2. Validation Points
1. Correct inventory detection
2. Proper credential extraction from group variables
3. Graceful error handling and user guidance
4. Performance (minimal API calls)
5. Backward compatibility with existing job templates

## Migration Plan

### Phase 1: Development and Testing
1. Create new playbook following proven Python script pattern
2. Test with known problematic hosts (`eboksweb2302`)
3. Validate credential discovery mechanism
4. Ensure error handling provides actionable feedback

### Phase 2: Job Template Updates
1. Remove hardcoded credentials from job templates
2. Update job templates to rely on dynamic credential discovery
3. Test with various customer inventories
4. Document new behavior for operators

### Phase 3: Production Deployment
1. Deploy new playbook to production
2. Monitor execution logs for any issues
3. Collect operator feedback
4. Optimize performance based on usage patterns

## Expected Benefits

### Operational Improvements
1. **Eliminate Manual Intervention**: Automatic inventory and credential detection
2. **Reduce Execution Time**: No need to retry with different inventories
3. **Improve Reliability**: Graceful handling of edge cases
4. **Better User Experience**: Clear error messages with actionable guidance

### Technical Improvements
1. **Code Reusability**: Single playbook works across all customer inventories
2. **Maintainability**: Centralized logic following proven patterns
3. **Scalability**: Easy to add new customer inventories
4. **Consistency**: Uniform behavior across all automation workflows

## Success Criteria

### Functional Requirements
- ✅ Automatically detect correct inventory for any Windows host
- ✅ Extract credentials from group variables (not hostname patterns)
- ✅ Provide comprehensive error handling with actionable guidance
- ✅ Support both single-host and inventory-wide execution modes
- ✅ Maintain backward compatibility with existing job templates

### Performance Requirements
- ✅ Complete host discovery within 30 seconds
- ✅ Minimize Tower/AWX API calls (≤5 calls per host discovery)
- ✅ Graceful timeout handling for API calls

### Quality Requirements
- ✅ Zero hard failures for valid Windows hosts in accepted inventories
- ✅ Clear, actionable error messages for invalid scenarios
- ✅ Comprehensive logging for troubleshooting
- ✅ Consistent behavior across all customer environments

## Conclusion

The redesign should follow the proven pattern from `launch_and_misc_awx_functions.py`, which already successfully handles cross-inventory host discovery and group-based credential extraction. This approach eliminates the need for hostname pattern matching and provides a robust, scalable solution for Windows server verification across all customer inventories.

The key insight is that the Python script already solves this exact problem - we need to translate its proven logic into Ansible playbook format while maintaining the same API interaction patterns and error handling philosophy.
