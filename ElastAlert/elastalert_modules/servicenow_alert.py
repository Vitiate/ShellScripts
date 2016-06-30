from alerts import Alerter, BasicMatchString
import requests
import json
class ServiceNowAlerter(Alerter):

    required_options = set(['username', 'password', 'servicenow_rest_url', 'short_description', 'comments', 'assignment_group', 'category', 'subcategory', 'cmdb_ci', 'caller_id'])

    # Alert is called
    def alert(self, matches):
        for match in matches:
            # Parse everything into description.
            description = str(BasicMatchString(self.rule, match))

        # Set proper headers
        headers = {
            "Content-Type":"application/json",
            "Accept":"application/json;charset=utf-8"
        }
        data = {
            "description": description, 
            "short_description": self.rule['short_description'],
            "comments": self.rule['comments'], 
            "assignment_group": self.rule['assignment_group'], 
            "category": self.rule['category'], 
            "subcategory": self.rule['subcategory'],
            "cmdb_ci": self.rule['cmdb_ci'],
            "caller_id": self.rule["caller_id"]
        }

        response = requests.post(self.rule['servicenow_rest_url'], auth=(self.rule['username'], self.rule['password']), headers=headers , data=json.dumps(data))
        if response.status_code != 201: 
            print('Status:', response.status_code, 'Headers:', response.headers, 'Error Response:',response.json())
            exit()

    # get_info is called after an alert is sent to get data that is written back
    # to Elasticsearch in the field "alert_info"
    # It should return a dict of information relevant to what the alert does
    def get_info(self):
        return {'type': 'Awesome Alerter',
                'SN_description': self.rule['description']}