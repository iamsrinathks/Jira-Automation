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

# --- Main execution ---
if __name__ == '__main__':
    # For development, runs on http://127.0.0.1:5000
    app.run(debug=True, port=5000)
