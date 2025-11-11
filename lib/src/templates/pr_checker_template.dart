const String getxPrCheckerTemplate = r'''#!/usr/bin/env python3
"""
GitLab Merge Request Checker - {{PROJECT_LABEL}}
Validates MR against Flutter/Dart project-specific rules.
"""

import os
import sys
import re
import requests
from typing import List, Dict, Tuple, Set

DEFAULT_GITLAB_TOKEN = {{GITLAB_TOKEN_LITERAL}}

class GetxMrChecker:
    """Handles all MR validation checks for {{PROJECT_LABEL}} Flutter project."""
    
    # Conventional Commit prefixes for Flutter project
    CONVENTIONAL_PREFIXES = [
        'feat', 'fix', 'docs', 'style', 'refactor', 
        'perf', 'test', 'build', 'ci', 'chore', 'revert'
    ]
    
    # Forbidden files and patterns
    FORBIDDEN_FILES = ['.env', 'secrets.json', '.env.local', '.env.production']
    SENSITIVE_PATTERNS = [
        r'.*private.*key.*',
        r'.*\.pem$',
        r'.*\.key$',
        r'.*\.keystore$',
        r'.*token.*\.txt$',
        r'.*credentials.*\.json$',
    ]
    
    # Flutter file naming patterns
    CONTROLLER_PATTERN = r'^[a-z_]+_controller\.dart$'
    PAGE_PATTERN = r'^[a-z_]+_page\.dart$'
    REPOSITORY_PATTERN = r'^[a-z_]+_repository\.dart$'
    
    # Code quality patterns
    HARDCODED_STRING_PATTERNS = [
        # Text widget with hardcoded string (exclude LocaleKeys and string interpolations)
        r'Text\s*\(\s*["\'](?!.*LocaleKeys)(?!.*\$\{).*["\']',  
        # showMessage with hardcoded string (exclude LocaleKeys and string interpolations)
        r'showMessage\s*\(\s*["\'](?!.*LocaleKeys)(?!.*\$\{).*["\']',  
    ]
    
    PRINT_PATTERNS = [
        r'\bprint\s*\(',  # print() statements
        r'\bconsole\.log\s*\(',  # console.log (shouldn't be in Dart but check anyway)
    ]
    
    TODO_WITHOUT_TICKET = r'//\s*TODO(?!:?\s*[A-Z]+-\d+)'  # TODO without TENT-XXX
    
    def __init__(self):
        """Initialize with GitLab CI environment variables."""
        self.api_url = os.getenv('CI_API_V4_URL', 'https://gitlab.com/api/v4')
        self.project_id = os.getenv('CI_PROJECT_ID')
        self.mr_iid = os.getenv('CI_MERGE_REQUEST_IID')
        self.token = os.getenv('GITLAB_TOKEN', DEFAULT_GITLAB_TOKEN or None)
        
        # Validate required environment variables
        if not all([self.project_id, self.mr_iid, self.token]):
            print("❌ ERROR: Missing required environment variables")
            print(f"   CI_PROJECT_ID: {'✓' if self.project_id else '✗'}")
            print(f"   CI_MERGE_REQUEST_IID: {'✓' if self.mr_iid else '✗'}")
            print(f"   GITLAB_TOKEN: {'✓' if self.token else '✗'}")
            sys.exit(1)
        
        self.headers = {
            'PRIVATE-TOKEN': self.token,
            'Content-Type': 'application/json'
        }
        
        # Cache for file contents to avoid redundant API calls
        self._file_cache: Dict[Tuple[str, str], str] = {}
        
    def get_mr_details(self) -> Dict:
        """Fetch MR details from GitLab API."""
        url = f"{self.api_url}/projects/{self.project_id}/merge_requests/{self.mr_iid}"
        try:
            response = requests.get(url, headers=self.headers, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"❌ Failed to fetch MR details: {e}")
            sys.exit(1)
    
    def get_mr_commits(self) -> List[Dict]:
        """Fetch all commits in the MR."""
        url = f"{self.api_url}/projects/{self.project_id}/merge_requests/{self.mr_iid}/commits"
        try:
            response = requests.get(url, headers=self.headers, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"❌ Failed to fetch commits: {e}")
            sys.exit(1)
    
    def get_mr_changes(self) -> List[Dict]:
        """Fetch file changes in the MR."""
        url = f"{self.api_url}/projects/{self.project_id}/merge_requests/{self.mr_iid}/changes"
        try:
            response = requests.get(url, headers=self.headers, timeout=30)
            response.raise_for_status()
            return response.json().get('changes', [])
        except requests.RequestException as e:
            print(f"❌ Failed to fetch MR changes: {e}")
            sys.exit(1)
    
    def get_file_content(self, file_path: str, ref: str = None) -> str:
        """Fetch file content from GitLab with caching."""
        if ref is None:
            # Get the source branch from MR details
            mr_details = self.get_mr_details()
            ref = mr_details.get('source_branch')
        
        # Check cache first
        cache_key = (file_path, ref or '')
        if cache_key in self._file_cache:
            return self._file_cache[cache_key]
        
        # URL encode the file path
        encoded_path = requests.utils.quote(file_path, safe='')
        url = f"{self.api_url}/projects/{self.project_id}/repository/files/{encoded_path}/raw?ref={ref}"
        
        try:
            response = requests.get(url, headers=self.headers, timeout=30)
            response.raise_for_status()
            content = response.text
            # Cache the result
            self._file_cache[cache_key] = content
            return content
        except requests.RequestException:
            return ""
    
    def check_title_conventional(self, title: str) -> Tuple[bool, str, List[str]]:
        """Check if MR title follows Conventional Commit format."""
        pattern = r'^(' + '|'.join(self.CONVENTIONAL_PREFIXES) + r')(\(.+\))?:\s.+'
        
        issues = []
        if re.match(pattern, title, re.IGNORECASE):
            return True, f"✅ **Title Format**: Valid Conventional Commit style", issues
        else:
            valid_examples = ', '.join([f'`{p}`' for p in self.CONVENTIONAL_PREFIXES[:6]])
            issues.append(f"Title must start with one of: {valid_examples}")
            issues.append(f"Example: `feat(login): add forgot password functionality`")
            return False, f"❌ **Title Format**: Must follow Conventional Commit style", issues
    
    def check_description_requirements(self, description: str) -> Tuple[bool, str, List[str]]:
        """Check if description meets project requirements."""
        desc = (description or '').strip()
        min_length = 10
        issues = []
        
        if len(desc) < min_length:
            issues.append(f"Description must be at least {min_length} characters")
            issues.append(f"Current length: {len(desc)} characters")
            return False, f"❌ **Description**: Too short ({len(desc)}/{min_length} characters)", issues
        
        # Check for description template sections
        has_description = '## Description' in desc or '## description' in desc.lower()
        has_type = '## Type of Change' in desc or 'type of change' in desc.lower()
        
        if not (has_description or has_type):
            issues.append("Consider using the MR description template")
            issues.append("Should include: Description, Type of Change, Related Tickets, etc.")
            return True, f"⚠️  **Description**: {len(desc)} characters (consider using template)", issues
        
        return True, f"✅ **Description**: {len(desc)} characters, follows template", issues
    
    def check_wip_commits(self, commits: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for WIP commits."""
        wip_commits = []
        issues = []
        
        for commit in commits:
            message = commit.get('message', '').lower()
            # Look for WIP at the beginning of commit message or title
            title = commit.get('title', '').lower()
            if (message.startswith('wip') or title.startswith('wip') or 
                message.startswith('[wip]') or title.startswith('[wip]')):
                short_sha = commit.get('short_id', commit.get('id', '')[:8])
                wip_commits.append(f"  - `{short_sha}`: {commit.get('title', 'N/A')}")
        
        if not wip_commits:
            return True, f"✅ **WIP Commits**: None found ({len(commits)} commits checked)", issues
        else:
            wip_list = '\n'.join(wip_commits)
            issues.append("Remove or squash WIP commits before merging")
            issues.extend(wip_commits)
            return False, f"❌ **WIP Commits**: Found {len(wip_commits)} commit(s):\n{wip_list}", issues
    
    def check_commit_messages(self, commits: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check if commit messages follow Conventional Commit format."""
        pattern = r'^(' + '|'.join(self.CONVENTIONAL_PREFIXES) + r')(\(.+\))?:\s.+'
        bad_commits = []
        issues = []
        
        for commit in commits:
            title = commit.get('title', '')
            if not re.match(pattern, title, re.IGNORECASE):
                short_sha = commit.get('short_id', commit.get('id', '')[:8])
                bad_commits.append(f"  - `{short_sha}`: {title[:60]}")
        
        if not bad_commits:
            return True, f"✅ **Commit Messages**: All follow Conventional Commits ({len(commits)} checked)", issues
        else:
            commits_list = '\n'.join(bad_commits[:5])  # Show first 5
            if len(bad_commits) > 5:
                commits_list += f"\n  - ... and {len(bad_commits) - 5} more"
            issues.append("Commit messages should follow format: `type(scope): description`")
            issues.extend(bad_commits[:5])
            return False, f"❌ **Commit Messages**: {len(bad_commits)} don't follow convention:\n{commits_list}", issues
    
    def check_sensitive_files(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for sensitive/forbidden files."""
        forbidden_found = []
        issues = []
        
        for change in changes:
            file_path = change.get('new_path', '')
            file_name = os.path.basename(file_path)
            
            # Check forbidden file names
            if file_name in self.FORBIDDEN_FILES:
                forbidden_found.append(f"  - `{file_path}` (forbidden file)")
                continue
            
            # Check sensitive patterns (use re.search for clearer semantics)
            for pattern in self.SENSITIVE_PATTERNS:
                if re.search(pattern, file_path, re.IGNORECASE):
                    forbidden_found.append(f"  - `{file_path}` (sensitive file pattern)")
                    break
        
        if not forbidden_found:
            return True, f"✅ **Sensitive Files**: None detected ({len(changes)} files checked)", issues
        else:
            files_list = '\n'.join(forbidden_found)
            issues.append("Remove sensitive files before merging")
            issues.extend(forbidden_found)
            return False, f"❌ **Sensitive Files**: Found {len(forbidden_found)} file(s):\n{files_list}", issues
    
    def check_file_naming_conventions(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check if Flutter files follow naming conventions."""
        violations = []
        issues = []
        
        for change in changes:
            file_path = change.get('new_path', '')
            
            # Only check Dart files in specific directories
            if not file_path.endswith('.dart'):
                continue
            
            file_name = os.path.basename(file_path)
            
            # Check controller files
            if '/controller/' in file_path and not re.match(self.CONTROLLER_PATTERN, file_name):
                violations.append(f"  - `{file_path}` should be `*_controller.dart`")
            
            # Check page/view files
            elif '/view/' in file_path and not re.match(self.PAGE_PATTERN, file_name):
                violations.append(f"  - `{file_path}` should be `*_page.dart`")
            
            # Check repository files
            elif '/repository/' in file_path and not re.match(self.REPOSITORY_PATTERN, file_name):
                violations.append(f"  - `{file_path}` should be `*_repository.dart`")
        
        if not violations:
            return True, f"✅ **File Naming**: All files follow conventions", issues
        else:
            violations_list = '\n'.join(violations[:10])
            if len(violations) > 10:
                violations_list += f"\n  - ... and {len(violations) - 10} more"
            issues.append("Files must follow naming conventions: *_controller.dart, *_page.dart, *_repository.dart")
            issues.extend(violations[:10])
            return False, f"❌ **File Naming**: {len(violations)} violation(s):\n{violations_list}", issues
    
    def check_folder_structure(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check if files are placed in correct folders."""
        violations = []
        issues = []
        
        for change in changes:
            file_path = change.get('new_path', '')
            
            if not file_path.endswith('.dart'):
                continue
            
            file_name = os.path.basename(file_path)
            
            # Controllers should be in controller/ folder
            if file_name.endswith('_controller.dart') and '/controller/' not in file_path:
                violations.append(f"  - `{file_path}` should be in a `controller/` folder")
            
            # Pages should be in view/ folder
            elif file_name.endswith('_page.dart') and '/view/' not in file_path:
                violations.append(f"  - `{file_path}` should be in a `view/` folder")
            
            # Repositories should be in repository/ folder
            elif file_name.endswith('_repository.dart') and '/repository/' not in file_path:
                violations.append(f"  - `{file_path}` should be in a `repository/` folder")
        
        if not violations:
            return True, f"✅ **Folder Structure**: All files properly organized", issues
        else:
            violations_list = '\n'.join(violations[:10])
            if len(violations) > 10:
                violations_list += f"\n  - ... and {len(violations) - 10} more"
            issues.append("Follow project structure: controllers in controller/, pages in view/, etc.")
            issues.extend(violations[:10])
            return False, f"❌ **Folder Structure**: {len(violations)} violation(s):\n{violations_list}", issues
    
    def check_hardcoded_strings(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for hardcoded strings in Dart files."""
        violations = []
        issues = []
        checked_files = 0
        checked_file_names = []
        
        for change in changes:
            file_path = change.get('new_path', '')
            
            # Only check Dart files in UI layer
            if not file_path.endswith('.dart') or '/ui/' not in file_path:
                continue
            
            checked_files += 1
            checked_file_names.append(file_path)
            content = self.get_file_content(file_path)
            
            if not content:
                continue
            
            # Check for hardcoded strings in Text widgets and messages
            for pattern in self.HARDCODED_STRING_PATTERNS:
                matches = re.finditer(pattern, content)
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    
                    # Get the line content for context checks
                    lines = content.split('\n')
                    current_line = lines[line_num - 1] if line_num <= len(lines) else ""
                    next_line = lines[line_num] if line_num < len(lines) else ""
                    prev_line = lines[line_num - 2] if line_num > 1 else ""
                    
                    # Skip Text.rich() and RichText() as they handle complex text structures
                    if re.search(r'Text\.rich\s*\(|RichText\s*\(', current_line):
                        continue

                    # Allow Dart string interpolation with $variable (without braces) and ${expr}
                    if ('$' in current_line and not re.search(r'\\\$', current_line)) or re.search(r'\$\{[^}]+\}', current_line):
                        continue

                    # Allow pure newline/tab/whitespace literals like "\n", "\t"
                    if re.search(r'["\']\s*\\[nrt]\s*["\']', current_line):
                        continue
                    
                    # Check for dynamic-related comments
                    dynamic_comment_patterns = [
                        r'//.*dynamic.*based.*on.*item',
                        r'//.*make.*dynamic.*based.*on',
                        r'//.*should.*be.*dynamic',
                        r'//.*can.*make.*dynamic',
                        r'//.*TODO.*dynamic',
                        r'//.*FIXME.*dynamic',
                        r'//.*dynamic.*properties',
                        r'//.*item\.properties',
                        r'//.*based.*on.*properties',
                    ]
                    
                    # Skip if any dynamic comment is found
                    should_skip = False
                    for comment_pattern in dynamic_comment_patterns:
                        if (re.search(comment_pattern, current_line, re.IGNORECASE) or
                            re.search(comment_pattern, next_line, re.IGNORECASE) or
                            re.search(comment_pattern, prev_line, re.IGNORECASE)):
                            should_skip = True
                            break
                    
                    if should_skip:
                        continue
                    
                    violations.append(f"  - `{file_path}:{line_num}` has hardcoded string")
                    if len(violations) >= 15:  # Limit to first 15
                        break
                if len(violations) >= 15:
                    break
            
            if len(violations) >= 15:
                break
        
        if not violations:
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return True, f"✅ **Hardcoded Strings**: None found ({checked_files} files checked: {files_list})", issues
        else:
            violations_list = '\n'.join(violations[:10])
            if len(violations) > 10:
                violations_list += f"\n  - ... and {len(violations) - 10} more"
            issues.append("Use LocaleKeys for all user-facing strings")
            issues.append("Example: `LocaleKeys.welcome.tr` instead of `'Welcome'`")
            issues.append("Note: String interpolations with variables or LocaleKeys are allowed")
            issues.append("Allowed: `'${item.name}'`, `'${LocaleKeys.price.tr}: ${item.price}'`")
            issues.append("Note: Strings with dynamic comments are excluded (e.g., `'Black', // can make dynamic`)")
            issues.extend(violations[:10])
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return False, f"❌ **Hardcoded Strings**: {len(violations)} found in {checked_files} files ({files_list}):\n{violations_list}", issues
    
    def check_print_statements(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for print() or console.log() statements."""
        violations = []
        issues = []
        checked_files = 0
        checked_file_names = []
        
        for change in changes:
            file_path = change.get('new_path', '')
            
            if not file_path.endswith('.dart'):
                continue
            
            checked_files += 1
            checked_file_names.append(file_path)
            content = self.get_file_content(file_path)
            
            if not content:
                continue
            
            # Check for print statements
            for pattern in self.PRINT_PATTERNS:
                matches = re.finditer(pattern, content)
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    violations.append(f"  - `{file_path}:{line_num}` contains print()")
                    if len(violations) >= 10:
                        break
                if len(violations) >= 10:
                    break
            
            if len(violations) >= 10:
                break
        
        if not violations:
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return True, f"✅ **Print Statements**: None found ({checked_files} files checked: {files_list})", issues
        else:
            violations_list = '\n'.join(violations[:10])
            if len(violations) > 10:
                violations_list += f"\n  - ... and {len(violations) - 10} more"
            issues.append("Remove print() statements or replace with debugPrint()")
            issues.extend(violations[:10])
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return False, f"❌ **Print Statements**: {len(violations)} found in {checked_files} files ({files_list}):\n{violations_list}", issues
    
    def check_todo_comments(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for TODO comments without ticket references."""
        violations = []
        issues = []
        checked_files = 0
        checked_file_names = []
        
        for change in changes:
            file_path = change.get('new_path', '')
            
            if not file_path.endswith('.dart'):
                continue
            
            checked_files += 1
            checked_file_names.append(file_path)
            content = self.get_file_content(file_path)
            
            if not content:
                continue
            
            # Check for TODO without ticket
            matches = re.finditer(self.TODO_WITHOUT_TICKET, content, re.IGNORECASE)
            for match in matches:
                line_num = content[:match.start()].count('\n') + 1
                violations.append(f"  - `{file_path}:{line_num}` has TODO without ticket")
                if len(violations) >= 10:
                    break
            
            if len(violations) >= 10:
                break
        
        if not violations:
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return True, f"✅ **TODO Comments**: All have ticket references ({checked_files} files checked: {files_list})", issues
        else:
            violations_list = '\n'.join(violations[:10])
            if len(violations) > 10:
                violations_list += f"\n  - ... and {len(violations) - 10} more"
            issues.append("TODO comments must reference a ticket: `// TODO: TENT-123 - description`")
            issues.extend(violations[:10])
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return False, f"⚠️  **TODO Comments**: {len(violations)} without ticket in {checked_files} files ({files_list}):\n{violations_list}", issues
    
    def check_broken_code_patterns(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for broken code patterns and missing flutter_screenutil utilities."""
        violations = []
        issues = []
        checked_files = 0
        checked_file_names = []
        
        # {{PROJECT_LABEL}} project's specific flutter_screenutil rules
        # Note: Excluding 0 values as they don't need ScreenUtil extensions
        broken_patterns = [
            # Hardcoded dimensions in SizedBox (only match numbers NOT followed by .h/.w, excluding 0)
            (r'SizedBox\(\s*height:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use \1.h instead of hardcoded height'),
            (r'SizedBox\(\s*width:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use \1.w instead of hardcoded width'),
            
            # Hardcoded dimensions in Container (only match numbers NOT followed by .h/.w, excluding 0)
            (r'Container\(\s*width:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use \1.w instead of hardcoded width'),
            (r'Container\(\s*height:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use \1.h instead of hardcoded height'),
            
            # Dimension variables without .h/.w extensions (like size_234, size_56)
            (r'width:\s*size_\d+(?![.\w])', 'Use .w extension for width dimension variables'),
            (r'height:\s*size_\d+(?![.\w])', 'Use .h extension for height dimension variables'),
            (r'Container\(\s*width:\s*size_\d+(?![.\w])', 'Use .w extension for width dimension variables'),
            (r'Container\(\s*height:\s*size_\d+(?![.\w])', 'Use .h extension for height dimension variables'),
            (r'SizedBox\(\s*width:\s*size_\d+(?![.\w])', 'Use .w extension for width dimension variables'),
            (r'SizedBox\(\s*height:\s*size_\d+(?![.\w])', 'Use .h extension for height dimension variables'),
            
            # Hardcoded font sizes (only match numbers not followed by .sp, excluding 0)
            (r'fontSize:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use \1.sp instead of hardcoded fontSize'),
            (r'TextStyle\(\s*fontSize:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use \1.sp instead of hardcoded fontSize'),
            
            # Hardcoded border radius (excluding 0)
            (r'BorderRadius\.circular\(\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use \1.r instead of hardcoded radius'),
            (r'Radius\.circular\(\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use \1.r instead of hardcoded radius'),
            (r'borderRadius:\s*BorderRadius\.circular\(\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use \1.r instead of hardcoded radius'),
            
            # {{PROJECT_LABEL}} specific EdgeInsets rules (excluding 0)
            # left/right use .w, top/bottom use .h, horizontal use .w, vertical use .h
            (r'EdgeInsets\.all\(\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use EdgeInsets.all(\1.w) for width-based padding'),
            (r'horizontal:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use horizontal: \1.w'),
            (r'vertical:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use vertical: \1.h'),
            (r'left:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use left: \1.w'),
            (r'right:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use right: \1.w'),
            (r'top:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use top: \1.h'),
            (r'bottom:\s*([1-9]\d*(?:\.\d+)?)(?![.\w])', 'Use bottom: \1.h'),
            
            # Hardcoded spacing in Column/Row (excluding 0)
            (r'children:\s*\[\s*SizedBox\(\s*height:\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use SizedBox(height: \1.h)'),
            (r'children:\s*\[\s*SizedBox\(\s*width:\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use SizedBox(width: \1.w)'),
            
            # Hardcoded BoxConstraints (excluding 0)
            (r'BoxConstraints\(\s*maxWidth:\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use maxWidth: \1.w'),
            (r'BoxConstraints\(\s*minWidth:\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use minWidth: \1.w'),
            (r'BoxConstraints\(\s*maxHeight:\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use maxHeight: \1.h'),
            (r'BoxConstraints\(\s*minHeight:\s*([1-9]\d*(?:\.\d+)?)\s*\)', 'Use minHeight: \1.h'),
        ]
        
        for change in changes:
            file_path = change.get('new_path', '')
            
            if not file_path.endswith('.dart'):
                continue
            
            # Skip generated files
            if any(skip in file_path for skip in ['/generated/', '.g.dart']):
                continue
            
            checked_files += 1
            checked_file_names.append(file_path)
            content = self.get_file_content(file_path)
            
            if not content:
                continue
            
            for pattern, description in broken_patterns:
                matches = re.finditer(pattern, content)
                for match in matches:
                    # Skip if it's a font variable (like font_16, font_14, etc.)
                    matched_text = match.group(0)
                    if re.search(r'fontSize:\s*font_\d+', matched_text):
                        continue
                    
                    line_num = content[:match.start()].count('\n') + 1
                    violations.append(f"  - `{file_path}:{line_num}` {description}")
                    if len(violations) >= 15:
                        break
                if len(violations) >= 15:
                    break
            
            if len(violations) >= 15:
                break
        
        if not violations:
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return True, f"✅ **Flutter ScreenUtil**: All patterns follow {{PROJECT_LABEL}} conventions ({checked_files} files checked: {files_list})", issues
        else:
            violations_list = '\n'.join(violations[:10])
            if len(violations) > 10:
                violations_list += f"\n  - ... and {len(violations) - 10} more"
            issues.append("{{PROJECT_LABEL}} flutter_screenutil rules:")
            issues.append("- Height: .h | Width: .w | Font Size: .sp | Radius: .r")
            issues.append("- Padding: left/right/horizontal → .w | top/bottom/vertical → .h")
            issues.append("- Note: 0 values don't need extensions (0.w, 0.h, 0.sp, 0.r are not required)")
            issues.append("Examples: 50.w, 100.h, 16.sp, 10.r, EdgeInsets.all(8.w), EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h)")
            issues.extend(violations[:10])
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return False, f"❌ **Flutter ScreenUtil**: {len(violations)} violation(s) in {checked_files} files ({files_list}):\n{violations_list}", issues
    
    def check_smart_widgets_usage(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for comprehensive Smart Widget usage and optimization."""
        violations = []
        issues = []
        checked_files = 0
        checked_file_names = []
        
        # Comprehensive Smart Widget replacement rules
        smart_widget_replacements = {
            # Core Layout Widgets (Critical)
            'Text': 'SmartText',
            'Row': 'SmartRow', 
            'Column': 'SmartColumn',
            
            # UI Component Widgets (Critical)
            'ElevatedButton': 'SmartButton',
            'TextButton': 'SmartButton',
            'OutlinedButton': 'SmartButton',
            'TextField': 'SmartTextField',
            'TextFormField': 'SmartTextField',
            'Checkbox': 'SmartCheckbox',
            'CheckboxListTile': 'SmartCheckbox',
            'Radio': 'SmartRadioButton',
            'RadioListTile': 'SmartRadioButton',
            'DropdownButton': 'SmartDropDown',
            'DropdownButtonFormField': 'SmartDropDown',
            'AppBar': 'SmartAppBar',
            'TabBar': 'SmartTabBar',
            'TabBarView': 'SmartTabBar',
            
            # Media & Display Widgets (Critical)
            'CircularProgressIndicator': 'SmartCircularProgressIndicator',
            'SingleChildScrollView': 'SmartSingleChildScrollView',
            
            # Utility Widgets (Important)
            'ExpansionTile': 'SmartExpansionTile',
            # Note: Divider and VerticalDivider are kept as-is since SmartDashedDivider is for dashed lines only
        }
        
        # Image widget patterns that should use SmartImage
        image_patterns = [
            r'Image\.asset\s*\(',
            r'Image\.network\s*\(',
            r'CachedNetworkImage\s*\(',
            r'SvgPicture\.asset\s*\(',
            r'SvgPicture\.network\s*\(',
        ]
        
        # Container with gradient patterns that should use SmartGradientContainer
        gradient_patterns = [
            r'Container\s*\(\s*[^)]*decoration:\s*BoxDecoration\s*\([^)]*gradient:',
            r'Container\s*\(\s*[^)]*decoration:\s*BoxDecoration\s*\([^)]*LinearGradient',
        ]
        
        for change in changes:
            file_path = change.get('new_path', '')
            
            # Only check Dart files in UI layer
            if not file_path.endswith('.dart') or '/ui/' not in file_path:
                continue
            
            # Skip generated files and widget definitions
            if any(skip in file_path for skip in ['/generated/', '.g.dart', '/widgets/smart_']):
                continue
            
            checked_files += 1
            checked_file_names.append(file_path)
            content = self.get_file_content(file_path)
            
            if not content:
                continue
            
            # Check for widget replacements using line-by-line analysis
            lines = content.split('\n')

            # If this file defines a Smart widget class, allow usage of its base widget here
            defined_smart_classes = {
                new_widget for new_widget in smart_widget_replacements.values()
                if re.search(rf"\bclass\s+{new_widget}\b", content)
            }
            
            # Special rule: If SmartTextField is present, skip SmartButton validation
            has_smart_text_field = any('SmartTextField' in line for line in lines)
            skip_button_validation = has_smart_text_field
            
            for line_idx, line in enumerate(lines):
                line_num = line_idx + 1
                
                # Skip comments
                if line.strip().startswith('//'):
                    continue
                
                # Check for widget replacements
                for old_widget, new_widget in smart_widget_replacements.items():
                    # Skip enforcing replacement inside the Smart widget's own implementation file
                    if new_widget in defined_smart_classes:
                        continue
                    # Skip if line already contains the Smart Widget
                    if new_widget in line:
                        continue
                    
                    # Special rule: Skip SmartButton validation when SmartTextField is present
                    if skip_button_validation and old_widget in ['ElevatedButton', 'TextButton', 'OutlinedButton']:
                        continue
                    
                    # Look for actual widget instantiations, not method names or string content
                    # Use word boundary to ensure we match widget class names, not method names
                    widget_pattern = rf'\b{old_widget}\s*\('
                    widget_match = re.search(widget_pattern, line)
                    if widget_match:
                        # Check if it's inside a string literal
                        before_match = line[:widget_match.start()]
                        quotes_before = before_match.count('"') + before_match.count("'")
                        
                        # If odd number of quotes, we're inside a string
                        if quotes_before % 2 == 1:
                            continue
                        
                        # Check if it's in a multi-line comment
                        if '/*' in content[:content.find(line)]:
                            comment_start = content.rfind('/*', 0, content.find(line))
                            comment_end = content.rfind('*/', 0, content.find(line))
                            if comment_start > comment_end:
                                continue
                        
                        # Check if it's part of a method name or property access
                        before_widget = line[:widget_match.start()].strip()
                        if (before_widget.endswith('.') or 
                            before_widget.endswith('(') or 
                            re.search(r'[a-zA-Z_][a-zA-Z0-9_]*$', before_widget)):
                            continue
                        
                        # Check if it's in a string interpolation, method call, or variable name
                        if ('.tr' in line or 
                            'LocaleKeys' in line or 
                            'clearTextField' in line or
                            'showMessage' in line or
                            'getHintText' in line or
                            'controller.' in line or
                            re.search(rf'{old_widget}\w+', line)):
                            continue
                        
                        # Additional validation: ensure it's actually a widget instantiation
                        # The widget pattern already ensures '(' follows, so no need for redundant check
                        
                        violations.append(f"  - `{file_path}:{line_num}` use {new_widget} instead of {old_widget}")
                        if len(violations) >= 15:
                            break
                
                # Check for Image widget patterns
                for pattern in image_patterns:
                    # Skip enforcing inside SmartImage's own implementation file
                    if 'SmartImage' in defined_smart_classes:
                        continue
                    image_match = re.search(pattern, line)
                    if image_match:
                        # Skip if line contains SmartImage
                        if 'SmartImage' in line:
                            continue
                        
                        # Check if it's inside a string literal
                        before_match = line[:image_match.start()]
                        quotes_before = before_match.count('"') + before_match.count("'")
                        
                        if quotes_before % 2 == 1:
                            continue
                        
                        # Extract the image widget name for better error message
                        image_widget_name = image_match.group(0).rstrip('(').strip()
                        violations.append(f"  - `{file_path}:{line_num}` use SmartImage instead of {image_widget_name}")
                        if len(violations) >= 15:
                            break
                
                # Check for gradient Container patterns
                for pattern in gradient_patterns:
                    # Skip enforcing inside SmartGradientContainer's own implementation file
                    if 'SmartGradientContainer' in defined_smart_classes:
                        continue
                    gradient_match = re.search(pattern, line)
                    if gradient_match:
                        # Skip if line contains SmartGradientContainer
                        if 'SmartGradientContainer' in line:
                            continue
                        
                        violations.append(f"  - `{file_path}:{line_num}` use SmartGradientContainer instead of Container with gradient")
                        if len(violations) >= 15:
                            break
                
                if len(violations) >= 15:
                    break
            
            if len(violations) >= 15:
                break
            
            # Check for unnecessary Container wrapping of Smart Widgets
            container_wrapping_patterns = [
                (r'Container\s*\(\s*[^)]*child:\s*SmartRow\s*\(', 'SmartRow already includes Container properties'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartColumn\s*\(', 'SmartColumn already includes Container properties'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartButton\s*\(', 'SmartButton already includes Container properties'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartTextField\s*\(', 'SmartTextField already includes Container properties'),
            ]
            
            for pattern, description in container_wrapping_patterns:
                matches = re.finditer(pattern, content, re.MULTILINE | re.DOTALL)
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    violations.append(f"  - `{file_path}:{line_num}` {description}")
                    if len(violations) >= 10:
                        break
                if len(violations) >= 10:
                    break
            
            if len(violations) >= 10:
                break
            
            # Check for underutilized Smart Widget properties
            smart_widget_usage_patterns = [
                # SmartRow/SmartColumn with Container wrapping (redundant)
                (r'Container\s*\(\s*[^)]*child:\s*SmartRow\s*\([^)]*padding:', 'Use SmartRow padding property instead of Container'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartRow\s*\([^)]*margin:', 'Use SmartRow margin property instead of Container'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartRow\s*\([^)]*decoration:', 'Use SmartRow decoration property instead of Container'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartColumn\s*\([^)]*padding:', 'Use SmartColumn padding property instead of Container'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartColumn\s*\([^)]*margin:', 'Use SmartColumn margin property instead of Container'),
                (r'Container\s*\(\s*[^)]*child:\s*SmartColumn\s*\([^)]*decoration:', 'Use SmartColumn decoration property instead of Container'),
                
                # Check for redundant Padding widget wrapping SmartText
                (r'Padding\s*\(\s*[^)]*child:\s*SmartText\s*\([^)]*optionalPadding:', 'SmartText already has optionalPadding property'),
                
                # Check for redundant GestureDetector wrapping SmartText with onTap
                (r'GestureDetector\s*\(\s*[^)]*onTap:[^)]*child:\s*SmartText\s*\([^)]*onTap:', 'SmartText already has onTap property'),
            ]
            
            for pattern, description in smart_widget_usage_patterns:
                matches = re.finditer(pattern, content, re.MULTILINE | re.DOTALL)
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    violations.append(f"  - `{file_path}:{line_num}` {description}")
                    if len(violations) >= 10:
                        break
                if len(violations) >= 10:
                    break
            
            if len(violations) >= 10:
                break
        
        if not violations:
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return True, f"✅ **Smart Widgets**: Properly used throughout ({checked_files} files checked: {files_list})", issues
        else:
            violations_list = '\n'.join(violations[:10])
            if len(violations) > 10:
                violations_list += f"\n  - ... and {len(violations) - 10} more"
            issues.append("📋 **Smart Widget Guidelines (20+ Widgets):**")
            issues.append("")
            issues.append("🎯 **Core Layout (Critical):**")
            issues.append("- SmartText → Text | SmartRow → Row | SmartColumn → Column")
            issues.append("")
            issues.append("🎨 **UI Components (Critical):**")
            issues.append("- SmartButton → ElevatedButton/TextButton/OutlinedButton")
            issues.append("- SmartTextField → TextField/TextFormField")
            issues.append("- SmartCheckbox → Checkbox | SmartRadioButton → Radio")
            issues.append("- SmartDropDown → DropdownButton | SmartAppBar → AppBar")
            issues.append("- SmartTabBar → TabBar/TabBarView")
            issues.append("")
            issues.append("🖼️ **Media & Display (Critical):**")
            issues.append("- SmartImage → Image.asset/Image.network/CachedNetworkImage/SvgPicture")
            issues.append("- SmartCircularProgressIndicator → CircularProgressIndicator")
            issues.append("- SmartSingleChildScrollView → SingleChildScrollView")
            issues.append("")
            issues.append("🔧 **Utility Widgets (Important):**")
            issues.append("- SmartExpansionTile → ExpansionTile")
            issues.append("- SmartDashedDivider → Use for dashed/dotted dividers (not regular Divider)")
            issues.append("- SmartGradientContainer → Container with gradients")
            issues.append("")
            issues.append("🏗️ **Advanced Architecture:**")
            issues.append("- SmartViewBuilder → Available for loading/error/success states (optional)")
            issues.append("- SmartPaginatedViewBuilder → Available for pagination (optional)")
            issues.append("")
            issues.append("⚠️ **Optimization Rules:**")
            issues.append("- Avoid wrapping Smart Widgets with Container (they include Container properties)")
            issues.append("- Use Smart Widget properties: padding, margin, decoration, color, onTap, etc.")
            issues.append("- SmartTextField presence skips SmartButton validation (forms may not need buttons)")
            issues.extend(violations[:10])
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return False, f"❌ **Smart Widgets**: {len(violations)} optimization(s) needed in {checked_files} files ({files_list}):\n{violations_list}", issues
    
    def check_api_keys_in_code(self, changes: List[Dict]) -> Tuple[bool, str, List[str]]:
        """Check for potential API keys or secrets in code."""
        violations = []
        issues = []
        checked_file_names = []
        
        # Patterns for potential secrets (more precise to avoid false positives)
        secret_patterns = [
            (r'api[_-]?key\s*[=:]\s*["\'][A-Za-z0-9\-_]{20,}["\']', 'API key'),
            (r'secret[_-]?key\s*[=:]\s*["\'][A-Za-z0-9\-_]{15,}["\']', 'Secret key'),
            (r'password\s*[=:]\s*["\'][A-Za-z0-9!@#$%^&*()_+\-=\[\]{};\':"\\|,.<>\/?]{8,}["\']', 'Password'),
            (r'token\s*[=:]\s*["\'][A-Za-z0-9\-_]{20,}["\']', 'Token'),
            (r'Bearer\s+[A-Za-z0-9\-_]{20,}', 'Bearer token'),
            (r'AIza[0-9A-Za-z\-_]{35}', 'Google API key'),
            (r'private[_-]?key\s*[=:]\s*["\'][A-Za-z0-9\-_]{30,}["\']', 'Private key'),
        ]
        
        checked_files = 0
        for change in changes:
            file_path = change.get('new_path', '')
            
            if not file_path.endswith('.dart'):
                continue
            
            # Skip test files and generated files
            if any(skip in file_path for skip in ['/test/', '_test.dart', '/generated/', '.g.dart']):
                continue
            
            checked_files += 1
            checked_file_names.append(file_path)
            content = self.get_file_content(file_path)
            
            if not content:
                continue
            
            for pattern, secret_type in secret_patterns:
                matches = re.finditer(pattern, content, re.IGNORECASE)
                for match in matches:
                    # Skip if it's a comment or obviously empty
                    matched_text = match.group(0)
                    
                    # Skip obvious false positives
                    if any(skip in matched_text.lower() for skip in [
                        'your_api_key', 'your_password', 'your_token',
                        'placeholder', 'example', 'sample',
                        'forgotpassword', 'resetpassword', 'refreshtoken', 'changepassword', 'change_password_page',  # API endpoints
                        'localekeys', 'static const', 'const string',  # Generated code
                        'enterpassword', 'currentpassword', 'newpassword', 'confirmpassword',  # LocaleKeys
                        'pleaseenterpassword', 'pleaseenterpasscode',  # More LocaleKeys
                        '""', "''", 'null', 'undefined',
                        '/mobile/user/', '/auth/',  # API URL patterns
                        "'enterpassword'", "'currentpassword'", "'newpassword'", "'confirmpassword'"  # LocaleKey strings
                    ]):
                        continue

                    # Skip if the line contains const/static/final declarations (for route definitions, etc.)
                    line_start = content.rfind('\n', 0, match.start()) + 1
                    line_end = content.find('\n', match.end())
                    if line_end == -1:
                        line_end = len(content)
                    full_line = content[line_start:line_end]
                    # Skip if line contains const/static/final declarations
                    if re.search(r'\b(const|static|final)\s+', full_line, re.IGNORECASE):
                        continue
                    
                    line_num = content[:match.start()].count('\n') + 1
                    violations.append(f"  - `{file_path}:{line_num}` potential {secret_type}")
                    if len(violations) >= 10:
                        break
                if len(violations) >= 10:
                    break
            
            if len(violations) >= 10:
                break
        
        if not violations:
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return True, f"✅ **API Keys/Secrets**: None detected ({checked_files} files checked: {files_list})", issues
        else:
            violations_list = '\n'.join(violations[:10])
            issues.append("Never commit API keys or secrets to the repository")
            issues.append("Use environment variables or Firebase Remote Config")
            issues.extend(violations[:10])
            files_list = ', '.join([f"`{f}`" for f in checked_file_names[:5]])
            if len(checked_file_names) > 5:
                files_list += f" and {len(checked_file_names) - 5} more"
            return False, f"❌ **API Keys/Secrets**: {len(violations)} potential leak(s) in {checked_files} files ({files_list}):\n{violations_list}", issues
    
    def post_comment(self, message: str):
        """Post a comment on the MR."""
        url = f"{self.api_url}/projects/{self.project_id}/merge_requests/{self.mr_iid}/notes"
        data = {'body': message}
        
        try:
            response = requests.post(url, headers=self.headers, json=data, timeout=30)
            response.raise_for_status()
            print("✅ Comment posted to MR successfully")
        except requests.RequestException as e:
            print(f"⚠️  Warning: Failed to post comment: {e}")
    
    def run_all_checks(self) -> bool:
        """Execute all validation checks and return overall pass/fail."""
        print("\n" + "="*70)
        print("🔍 {{PROJECT_LABEL}} - GitLab MR Checker")
        print("="*70 + "\n")
        
        # Fetch MR data
        print("📥 Fetching MR details...")
        mr_details = self.get_mr_details()
        title = mr_details.get('title', '')
        description = mr_details.get('description', '')
        
        print("📥 Fetching commits...")
        commits = self.get_mr_commits()
        
        print("📥 Fetching file changes...")
        changes = self.get_mr_changes()
        
        print(f"\n📋 MR Info:")
        print(f"   Title: {title}")
        print(f"   Commits: {len(commits)}")
        print(f"   Files Changed: {len(changes)}")
        print("\n" + "-"*70 + "\n")
        
        # Run all checks
        all_checks = []
        all_issues = {}
        
        # Basic checks (info level - not blocking)
        passed, msg, issues = self.check_title_conventional(title)
        all_checks.append((passed, msg, 'info'))
        if issues:
            all_issues['Title Format'] = issues
        
        passed, msg, issues = self.check_description_requirements(description)
        all_checks.append((passed, msg, 'info'))
        if issues:
            all_issues['Description'] = issues
        
        # Commit checks (WIP commits are critical - blocking)
        passed, msg, issues = self.check_wip_commits(commits)
        all_checks.append((passed, msg, 'critical'))
        if issues:
            all_issues['WIP Commits'] = issues
        
        passed, msg, issues = self.check_commit_messages(commits)
        all_checks.append((passed, msg, 'info'))
        if issues:
            all_issues['Commit Messages'] = issues
        
        # Security checks
        passed, msg, issues = self.check_sensitive_files(changes)
        all_checks.append((passed, msg, 'critical'))
        if issues:
            all_issues['Sensitive Files'] = issues
        
        passed, msg, issues = self.check_api_keys_in_code(changes)
        all_checks.append((passed, msg, 'critical'))
        if issues:
            all_issues['API Keys/Secrets'] = issues
        
        # Flutter-specific checks
        passed, msg, issues = self.check_file_naming_conventions(changes)
        all_checks.append((passed, msg, 'warning'))
        if issues:
            all_issues['File Naming'] = issues
        
        passed, msg, issues = self.check_folder_structure(changes)
        all_checks.append((passed, msg, 'warning'))
        if issues:
            all_issues['Folder Structure'] = issues
        
        passed, msg, issues = self.check_hardcoded_strings(changes)
        all_checks.append((passed, msg, 'warning'))
        if issues:
            all_issues['Hardcoded Strings'] = issues
        
        passed, msg, issues = self.check_print_statements(changes)
        all_checks.append((passed, msg, 'warning'))
        if issues:
            all_issues['Print Statements'] = issues
        
        passed, msg, issues = self.check_todo_comments(changes)
        all_checks.append((passed, msg, 'info'))
        if issues:
            all_issues['TODO Comments'] = issues
        
        # Code quality checks - flutter_screenutil violations are critical
        passed, msg, issues = self.check_broken_code_patterns(changes)
        all_checks.append((passed, msg, 'critical'))
        if issues:
            all_issues['Flutter ScreenUtil'] = issues
        
        # Smart Widget usage check - critical for code consistency
        passed, msg, issues = self.check_smart_widgets_usage(changes)
        all_checks.append((passed, msg, 'critical'))
        if issues:
            all_issues['Smart Widgets'] = issues
        
        # Print results to console
        critical_failures = 0
        warnings = 0
        info_issues = 0
        
        for passed, message, severity in all_checks:
            print(message)
            print()
            if not passed:
                if severity == 'critical':
                    critical_failures += 1
                elif severity == 'warning':
                    warnings += 1
                elif severity == 'info':
                    info_issues += 1
        
        # Build comment for MR - focus on critical issues only
        all_passed = critical_failures == 0
        
        if all_passed:
            if warnings == 0:
                status_emoji = "✅ **CODE QUALITY CHECKS PASSED**"
            else:
                status_emoji = f"⚠️  **PASSED WITH {warnings} WARNING(S)**"
            
            if info_issues > 0:
                status_emoji += f"\n\nℹ️  **{info_issues} SUGGESTION(S)** (non-blocking)"
        else:
            status_emoji = f"❌ **BLOCKING ISSUES FOUND** ({critical_failures} critical issue(s))"
        
        comment = f"""## 🤖 {{PROJECT_LABEL}} Code Quality Check

{status_emoji}

> **Focus**: Code quality, security, and maintainability. Process suggestions are non-blocking.

---

### Check Summary

"""
        
        for passed, message, severity in all_checks:
            comment += message + "\n\n"
        
        # Add detailed issues if any
        if all_issues:
            comment += "\n---\n\n### 📋 Details & Recommendations\n\n"
            for check_name, issue_list in all_issues.items():
                if issue_list:
                    comment += f"**{check_name}:**\n"
                    for issue in issue_list[:5]:  # Limit to first 5 issues per check
                        comment += f"{issue}\n"
                    comment += "\n"
        
        comment += """---

### 📚 Quick References

- **Conventional Commits**: `type(scope): description` where type is feat, fix, docs, etc.
- **File Naming**: Controllers: `*_controller.dart`, Pages: `*_page.dart`
- **Localization**: Use `LocaleKeys.keyName.tr` instead of hardcoded strings
- **TODO Format**: `// TODO: TENT-123 - description`
- **Smart Widgets**: Use SmartText/Row/Column instead of basic widgets
- **Flutter ScreenUtil**: Use .w/.h/.sp/.r extensions for responsive design

For full guidelines, see the project's MR rules documentation.

---

*Generated by {{PROJECT_LABEL}} GitLab CI MR Checker*
"""
        
        # Post comment to MR
        self.post_comment(comment)
        
        # Print final result
        print("-"*70)
        if all_passed:
            if warnings > 0:
                print(f"⚠️  Code quality checks PASSED with {warnings} warning(s)")
            else:
                print("✅ Code quality checks PASSED")
            
            if info_issues > 0:
                print(f"ℹ️  {info_issues} suggestion(s) for process improvements (non-blocking)")
        else:
            print(f"❌ {critical_failures} blocking issue(s) found - fix required")
        print("="*70 + "\n")
        
        return all_passed


def main():
    """Main entry point."""
    checker = GetxMrChecker()
    passed = checker.run_all_checks()
    
    # Exit with appropriate code (only fail on critical issues)
    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
''';
