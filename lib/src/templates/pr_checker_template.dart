const String getxPrCheckerTemplate = r'''#!/usr/bin/env python3
import os
import sys
import subprocess
import re
import argparse
import requests
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# --- Configuration ---
FAILURES = []
WARNINGS = []

PROJECT_NAME = "{{PROJECT_LABEL}}"
DEFAULT_GITLAB_TOKEN = {{GITLAB_TOKEN_LITERAL}}
EMAIL_RECIPIENTS = {{EMAIL_RECIPIENTS_LITERAL}}

# SMTP Configuration
SMTP_SERVER = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', '587'))
SMTP_USER = os.getenv('SMTP_USER')
SMTP_PASSWORD = os.getenv('SMTP_PASSWORD')
SMTP_SENDER = os.getenv('SMTP_SENDER', SMTP_USER)

class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_header(title):
    print(f"\n{Colors.HEADER}{Colors.BOLD}=== {PROJECT_NAME}: {title} ==={Colors.ENDC}")

def print_success(msg):
    print(f"{Colors.OKGREEN}✓ {msg}{Colors.ENDC}")

def print_error(msg):
    print(f"{Colors.FAIL}✗ {msg}{Colors.ENDC}")
    FAILURES.append(msg)

def print_warning(msg):
    print(f"{Colors.WARNING}! {msg}{Colors.ENDC}")
    WARNINGS.append(msg)

def run_command(command, cwd=None, exit_on_fail=False):
    """Runs a shell command and returns the output and exit code."""
    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        if exit_on_fail and result.returncode != 0:
            print_error(f"Command failed: {command}")
            print(result.stdout)
            sys.exit(1)
        return result.returncode, result.stdout
    except Exception as e:
        print_error(f"Exception while running {command}: {e}")
        if exit_on_fail:
            sys.exit(1)
        return 1, str(e)

# --- Phase 1: Environment & Context Gathering ---
def verify_flutter_env():
    print_header("Verifying Flutter Environment")
    code, out = run_command("flutter --version")
    if code != 0:
        print_error("Flutter is not installed or not in PATH.")
        sys.exit(1)
    
    lines = out.split('\n')
    if lines:
        print_success(f"Found {lines[0]}")
    else:
        print_warning("Could not parse Flutter version.")

def get_changed_files(base_branch):
    """Gets a list of changed .dart and .yaml files compared to the base branch."""
    print_header("Gathering Changed Files")
    if not base_branch:
        print_warning("No base branch specified. We will analyze the entire lib/ folder.")
        return []

    code, out = run_command(f"git diff --name-only {base_branch}...HEAD")
    if code != 0:
        print_error(f"Failed to get git diff. Are you in a git repository? Output:\n{out}")
        return []

    files = out.strip().split('\n')
    dart_and_yaml_files = [f for f in files if f.endswith('.dart') or f.endswith('.yaml')]
    
    print_success(f"Found {len(dart_and_yaml_files)} modified .dart/.yaml files.")
    for f in dart_and_yaml_files:
        print(f"  - {f}")
    
    return dart_and_yaml_files

# --- Phase 2: Static Analysis & Code Cleanliness ---
def run_flutter_analyze():
    print_header("Running Flutter Analyze")
    code, out = run_command("flutter analyze")
    if code == 0:
        print_success("Flutter analyze passed with no issues.")
    else:
        print_error("Flutter analyze failed. Please fix the warnings/errors.")
        print(out)

def run_dart_format():
    print_header("Running Dart Format Check")
    # --set-exit-if-changed returns 1 if files were formatted
    code, out = run_command("dart format --output=none --set-exit-if-changed .")
    if code == 0:
        print_success("All files are correctly formatted.")
    else:
        print_error("Some files are not formatted correctly. Please run 'dart format .' locally.")
        
def check_todos_and_secrets(files_to_check):
    print_header("Checking for Secrets")
    
    if not files_to_check:
        files_to_check = []
        for root, _, files in os.walk('lib'):
            for f in files:
                if f.endswith('.dart'):
                    files_to_check.append(os.path.join(root, f))
                    
    secret_regex = re.compile(r'(api_key|secret|token)\s*=\s*[\'"][A-Za-z0-9_\-]{20,}[\'"]', re.IGNORECASE)

    issues_found = False
    
    for file_path in files_to_check:
        if not os.path.exists(file_path):
            continue
            
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        for i, line in enumerate(lines):
            line_num = i + 1
            if secret_regex.search(line):
                print_error(f"{file_path}:{line_num} -> Potential hardcoded secret or token found.")
                issues_found = True

    if not issues_found:
        print_success("No hardcoded secrets found.")

# --- Phase 3: Architectural Boundary Enforcement ---
def enforce_architecture(files_to_check):
    print_header("Enforcing Architectural Boundaries")
    
    if not files_to_check:
        files_to_check = []
        for root, _, files in os.walk('lib'):
            for f in files:
                if f.endswith('.dart'):
                    files_to_check.append(os.path.join(root, f))
    
    issues_found = False
    forbidden_import_pattern = re.compile(r'import\s+[\'"]package:[^/]+/data/network/client/.*[\'"]')
    forbidden_relative_import_pattern = re.compile(r'import\s+[\'"].*data/network/client/.*[\'"]')
    
    for file_path in files_to_check:
        if not os.path.exists(file_path):
            continue
            
        # Check UI boundary and screenutil usage
        if 'lib/ui/' in file_path:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Architectural Rule
            if forbidden_import_pattern.search(content) or forbidden_relative_import_pattern.search(content):
                print_error(f"{file_path} -> UI layer should not directly import data/network/client. Use Repositories instead.")
                issues_found = True

            # flutter_screenutil Enforcement Rule
            # Catch raw hardcoded values like height: 20 or width: 20.0 instead of 20.h or 20.0.w
            # Using negative lookahead to ignore if it already has .h, .w, .sp, .r, or .sw/.sh
            # We target specific common sizing properties to avoid false positives (like index == 0 or maxLines: 2)
            # Skip this check for common widgets located in lib/ui/widgets/
            if 'lib/ui/widgets/' not in file_path:
                sizing_properties = re.compile(
                    r'(width|height|size|radius|fontSize|elevation|spacing|runSpacing)\s*:\s*\d+(\.\d+)?(?!\.(h|w|sp|r|sw|sh|[a-zA-Z]+))',
                    re.IGNORECASE
                )
                
                # Find all matches and their line numbers
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if sizing_properties.search(line):
                        print_warning(f"{file_path}:{i+1} -> Missing flutter_screenutil extension (.h, .w, .sp, .r) on sizing property. Use responsive sizing.")
                        issues_found = True
                
        # Naming convention check for snake_case
        basename = os.path.basename(file_path)
        if not re.match(r'^[a-z0-9_]+(\.g)?\.dart$', basename) and file_path.endswith('.dart'):
            print_error(f"{file_path} -> Filename must be in snake_case format.")
            issues_found = True
            
        # Controllers should end with _controller.dart
        if 'controller/' in file_path and file_path.endswith('.dart'):
            if basename != 'exports.dart' and not basename.endswith('_controller.dart'):
                print_error(f"{file_path} -> Controller files must end with '_controller.dart'.")
                issues_found = True

    if not issues_found:
        print_success("Architectural boundaries and naming conventions respected.")



# --- Phase 5: Git & PR Conventions ---
def check_pr_title(pr_title):
    print_header("Checking PR Title")
    if not pr_title:
        print_warning("No PR title provided to check.")
        return
        
    pattern = re.compile(r'^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9\-]+\))?:\s.+')
    if pattern.match(pr_title):
        print_success(f"PR title '{pr_title}' is valid.")
    else:
        print_error(f"PR title '{pr_title}' does not follow conventional commits (e.g., 'feat: added login UI').")

def check_branch_name(branch_name):
    print_header("Checking Branch Name")
    if not branch_name:
        print_warning("No branch name provided to check.")
        return
        
    pattern = re.compile(r'^(feature|bugfix|hotfix|chore)/[a-zA-Z0-9\-]+$')
    if pattern.match(branch_name):
        print_success(f"Branch name '{branch_name}' is valid.")
    else:
        print_error(f"Branch name '{branch_name}' is invalid. Use feature/..., bugfix/..., chore/..., hotfix/...")

def post_comment(message):
    api_url = os.getenv('CI_API_V4_URL', 'https://gitlab.com/api/v4')
    project_id = os.getenv('CI_PROJECT_ID')
    mr_iid = os.getenv('CI_MERGE_REQUEST_IID')
    
    token = os.getenv('GITLAB_TOKEN', DEFAULT_GITLAB_TOKEN)
    job_token = os.getenv('CI_JOB_TOKEN')

    if not project_id or not mr_iid:
        print_warning("Skipping MR comment; required env variables not found (CI_PROJECT_ID, CI_MERGE_REQUEST_IID).")
        return

    headers = {'Content-Type': 'application/json'}
    if token:
        headers['PRIVATE-TOKEN'] = token
    elif job_token:
        headers['JOB-TOKEN'] = job_token
    else:
        print_warning("Skipping MR comment; neither GITLAB_TOKEN nor CI_JOB_TOKEN found.")
        return

    url = f"{api_url}/projects/{project_id}/merge_requests/{mr_iid}/notes"
    data = {'body': message}
    
    try:
        response = requests.post(url, headers=headers, json=data, timeout=30)
        response.raise_for_status()
        print_success("Comment posted to MR successfully")
    except Exception as e:
        print_warning(f"Failed to post comment: {e}")

def send_email_report(status, report_body):
    if not EMAIL_RECIPIENTS or not SMTP_USER or not SMTP_PASSWORD:
        print_warning("Email notification skipped: Missing SMTP configuration or recipients")
        return
        
    print_header("Sending Email Notifications")
    
    mr_iid = os.getenv('CI_MERGE_REQUEST_IID', 'Unknown')
    
    try:
        html_body = f"""
        <html>
            <body style="font-family: sans-serif; line-height: 1.6; color: #333;">
                <div style="padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
                    <h2 style="color: #2c3e50;">{status}</h2>
                    <div style="background-color: #f9f9f9; padding: 15px; border-left: 5px solid #3498db; margin: 20px 0;">
                        {report_body.replace(chr(10), '<br>')}
                    </div>
                    <p style="font-size: 0.8em; color: #777; border-top: 1px solid #eee; padding-top: 10px; margin-top: 20px;">
                        This is an automated report from the {PROJECT_NAME} Code Quality Checker CI pipeline.
                    </p>
                </div>
            </body>
        </html>
        """

        msg = MIMEMultipart()
        msg['From'] = f"{PROJECT_NAME} CI <{SMTP_SENDER}>"
        msg['To'] = ", ".join(EMAIL_RECIPIENTS)
        msg['Subject'] = f"Code Quality Report: {status} - MR !{mr_iid}"

        msg.attach(MIMEText(html_body, 'html'))

        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
            
        print_success("Email report sent successfully")
    except Exception as e:
        print_warning(f"Failed to send email report: {e}")

# --- Main Execution ---
def main():
    parser = argparse.ArgumentParser(description="Flutter PR Checker")
    parser.add_argument('--base-branch', type=str, help='The base branch to compare against (e.g., origin/main or develop)')
    parser.add_argument('--pr-title', type=str, help='The title of the Pull Request (for conventional commits check)')
    parser.add_argument('--branch-name', type=str, help='The current branch name (for branch naming check)')
    
    args = parser.parse_args()

    verify_flutter_env()
    
    changed_files = get_changed_files(args.base_branch)
    
    run_dart_format()
    run_flutter_analyze()
    
    check_todos_and_secrets(changed_files)
    enforce_architecture(changed_files)
        
    if args.pr_title:
        check_pr_title(args.pr_title)
        
    if args.branch_name:
        check_branch_name(args.branch_name)

    # Summary
    print("\n" + "="*40)
    print(f"{Colors.BOLD}{PROJECT_NAME} PR CHECK SUMMARY{Colors.ENDC}")
    print("="*40)
    
    comment_body = f"## 🤖 {PROJECT_NAME} PR Quality Check\n\n"
    
    status_emoji = ""
    if len(FAILURES) == 0:
        status_emoji = "✅ All checks passed!"
        comment_body += "✅ **All checks passed!** The PR is ready to roll. 🎉\n"
        if len(WARNINGS) > 0:
            comment_body += "\n### ⚠️ Warnings:\n"
            for warning in WARNINGS:
                comment_body += f"- {warning}\n"
    else:
        status_emoji = f"❌ {len(FAILURES)} checks failed"
        comment_body += "❌ **The following checks failed:**\n\n"
        for i, failure in enumerate(FAILURES):
            comment_body += f"{i+1}. {failure}\n"
        
        if len(WARNINGS) > 0:
            comment_body += "\n### ⚠️ Warnings:\n"
            for warning in WARNINGS:
                comment_body += f"- {warning}\n"
                
        comment_body += "\n*Please fix the issues above and push again.*"
        
    post_comment(comment_body)
    send_email_report(status_emoji, comment_body)
    
    if len(FAILURES) == 0:
        print(f"{Colors.OKGREEN}{Colors.BOLD}🎉 All checks passed! The PR is ready to roll. 🎉{Colors.ENDC}")
        sys.exit(0)
    else:
        print(f"{Colors.FAIL}{Colors.BOLD}❌ The following checks failed:{Colors.ENDC}")
        for i, failure in enumerate(FAILURES):
            print(f"  {i+1}. {failure}")
        print("\nPlease fix the issues above and push again.")
        sys.exit(1)

if __name__ == "__main__":
    main()
''';
