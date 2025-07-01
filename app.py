import os
import requests
from flask import Flask, jsonify, request
from flask_cors import CORS
from requests.auth import HTTPBasicAuth

# --- 1. Initialize the Flask App ---
app = Flask(__name__)
# IMPORTANT: Enable CORS to allow your Backstage frontend to call this API
CORS(app) 

# --- 2. JIRA Configuration ---
# Best practice: Load credentials from environment variables, not in the code.
# In your terminal before running:
# export JIRA_URL='https://your-company.atlassian.net'
# export JIRA_EMAIL='your-email@company.com'
# export JIRA_API_TOKEN='YourGeneratedAPIToken'
# export JIRA_PROJECT_KEY='PROJ'

JIRA_URL = os.environ.get("JIRA_URL")
JIRA_EMAIL = os.environ.get("JIRA_EMAIL")
JIRA_API_TOKEN = os.environ.get("JIRA_API_TOKEN")
JIRA_PROJECT_KEY = os.environ.get("JIRA_PROJECT_KEY")

# --- 3. Authentication and Headers ---
if not all([JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN, JIRA_PROJECT_KEY]):
    raise ValueError("JIRA environment variables are not fully set!")

AUTH = HTTPBasicAuth(JIRA_EMAIL, JIRA_API_TOKEN)
HEADERS = {"Accept": "application/json"}

# --- 4. Reusable JIRA API Helper Function ---
def jira_search(jql, fields=None, max_results=0):
    """
    Performs a JIRA search and returns the JSON response.
    - jql: The JQL query string.
    - fields: A list of fields to retrieve.
    - max_results: Number of issues to return. 0 is useful for getting only the total count.
    """
    api_url = f"{JIRA_URL}/rest/api/3/search"
    
    payload = {
        'jql': jql,
        'maxResults': max_results,
        'startAt': 0
    }
    if fields:
        payload['fields'] = fields

    try:
        response = requests.post(api_url, json=payload, headers=HEADERS, auth=AUTH)
        response.raise_for_status()  # This will raise an HTTPError for bad responses (4xx or 5xx)
        return response.json()
    except requests.exceptions.RequestException as e:
        # Log the error and return a structured error response
        print(f"Error calling JIRA API: {e}")
        # In a real app, you might return a more specific error message
        return None 

# --- 5. Health Check Endpoint ---
@app.route('/api/health', methods=['GET'])
def health_check():
    """A simple endpoint to confirm the API is running."""
    return jsonify({"status": "ok"}), 200

#  API Endpoint for Features
@app.route('/api/features', methods=['GET'])
def get_features():
    """
    API to get a list of features (Epics), optionally filtered by a team.
    The custom field name 'Feature Team' must match exactly what is in JIRA.
    Query parameter: ?team=TeamName
    """
    team = request.args.get('team')
    
    # NOTE: In JQL, custom field names with spaces must be in quotes.
    # Replace 'Feature Team' with your actual custom field name.
    base_jql = f"project = {JIRA_PROJECT_KEY} AND issuetype = Epic"
    
    if team:
        base_jql += f' AND "Feature Team" = "{team}"'
        
    jql = f"{base_jql} ORDER BY created DESC"
    
    # We only need the key and summary for the dropdown
    issue_data = jira_search(jql, fields=['summary'], max_results=100)
    
    if issue_data is None:
        return jsonify({"error": "Failed to fetch data from JIRA"}), 502

    features = [
        {'key': issue['key'], 'summary': issue['fields']['summary']}
        for issue in issue_data.get('issues', [])
    ]
    
    return jsonify(features)

# API Endpoint for Progress Bars 

@app.route('/api/progress/<string:feature_key>', methods=['GET'])
def get_progress(feature_key):
    """
    Calculates the completion percentage for various task categories under a given feature.
    Categories are defined by labels.
    """
    # These are the labels you want to track progress for
    progress_labels = ["infrastructure", "security", "governance", "discovery"]
    progress_data = {}

    for label in progress_labels:
        # JQL to find all issues under the epic with the specific label
        total_jql = f'"Epic Link" = {feature_key} AND labels = {label}'
        
        # JQL to find all *completed* issues from the above set
        # statusCategory is more reliable than status="Done" as it covers all 'done' statuses
        done_jql = f'{total_jql} AND statusCategory = Done'
        
        total_issues_data = jira_search(total_jql, max_results=0)
        done_issues_data = jira_search(done_jql, max_results=0)

        if total_issues_data is None or done_issues_data is None:
            return jsonify({"error": f"Failed to fetch progress for label '{label}'"}), 502

        total_count = total_issues_data.get('total', 0)
        done_count = done_issues_data.get('total', 0)
        
        percentage = (done_count / total_count * 100) if total_count > 0 else 0
        
        # Use a more descriptive key for the response
        progress_data[f"{label}_progress_percent"] = round(percentage)
        
    return jsonify(progress_data)

# API Endpoint for Security Guardrail Stats 

@app.route('/api/guardrails/<string:feature_key>', methods=['GET'])
def get_guardrail_stats(feature_key):
    """
    Provides a breakdown of counts for a specific guardrail type under a feature.
    Query parameter: ?type=gcp-sha-gr
    """
    guardrail_type = request.args.get('type')
    
    if not guardrail_type:
        return jsonify({"error": "Query parameter 'type' is required."}), 400

    base_jql = f'"Epic Link" = {feature_key} AND labels = "{guardrail_type}"'
    
    # Define statuses. These must match your JIRA workflow exactly.
    live_status = "Live"  # Or "Done", "Closed", etc.
    rejected_status = "Rejected"
    
    # JQL for each metric
    jql_queries = {
        "total": base_jql,
        "live": f'{base_jql} AND status = "{live_status}"',
        "rejected": f'{base_jql} AND status = "{rejected_status}"',
        "in_progress": f'{base_jql} AND statusCategory = "In Progress"',
    }

    stats = {}
    for key, jql in jql_queries.items():
        result_data = jira_search(jql, max_results=0)
        if result_data is None:
            return jsonify({"error": f"Failed to fetch guardrail data for metric '{key}'"}), 502
        stats[key] = result_data.get('total', 0)

    return jsonify(stats)

# API Endpoint for the Task Table 

@app.route('/api/tasks/<string:feature_key>', methods=['GET'])
def get_tasks_for_feature(feature_key):
    """
    Retrieves a list of tasks (summary, status, due date) for a given feature.
    """
    jql = f'"Epic Link" = {feature_key} ORDER BY duedate ASC, created DESC'
    
    # We need specific fields, and this time we need the actual issues, not just counts.
    fields_to_get = ['summary', 'status', 'duedate']
    issue_data = jira_search(jql, fields=fields_to_get, max_results=200)

    if issue_data is None:
        return jsonify({"error": "Failed to fetch tasks from JIRA"}), 502

    tasks = []
    for issue in issue_data.get('issues', []):
        tasks.append({
            "summary": issue['fields'].get('summary'),
            "status": issue['fields'].get('status', {}).get('name'), # Safely access nested status name
            "due_date": issue['fields'].get('duedate')
        })
        
    return jsonify(tasks)

# --- Main execution ---
if __name__ == '__main__':
    # For development, runs on http://127.0.0.1:5000
    app.run(debug=True, port=5000)

