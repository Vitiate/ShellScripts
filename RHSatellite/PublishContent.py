#!/usr/bin/python
import json
import commands
import getopt, sys
from itertools import imap

def printHelp( int ):
	print 'PublishContent.py -c <ContentView> -v <CompositeContentView> -e <LifeCycleEnvironment>'
	print '	-c, --cview 		- Content View to publish'
	print '	-v, --ccview 		- Composite Content View to update with the new Content View Component and Publish'
	print '	-e, --environment 	- Life Cycle Environment to publish the Composite Content View to'
	sys.exit(int)

def main(argv):
	
	str_CV_Publish = ''
	str_CCV_Publish = ''
	str_ENV_Promote = ''
	
	try:
	    opts, args = getopt.getopt(argv,"hc:v:e:o:",["cview=","ccview=","environment="])
	except getopt.GetoptError:
		printHelp(2)
	for opt, arg in opts:
		if opt == '-h':
			printHelp(2)
		elif opt in ("-c", "--cview"):
			str_CV_Publish = arg
		elif opt in ("-v", "--ccview"):
			str_CCV_Publish = arg
		elif opt in ("-e", "--environment"):
			str_ENV_Promote = arg

	if str_CV_Publish == '':
		printHelp(2)
	if str_CCV_Publish == '':
		printHelp(2)
	if str_ENV_Promote == '':
		printHelp(2)


	# Setup hammer command to publish the product
	bash_CV_Publish = "hammer content-view publish --organization='AU' --name='" + str_CV_Publish +"'"
	print 'Publishing: ' + bash_CV_Publish
	# Publish the product
	ret_CV_Command = commands.getoutput(bash_CV_Publish)
	print 'Complete: ' + ret_CV_Command

	# Setup hammer command to obtain CV info
	bash_CV_Info = "hammer --output=json content-view info --organization='AU' --name='" + str_CV_Publish + "'"
	# Get the CV Info
	print 'Obtaining info on: ' + str_CV_Publish
	json_CV_Info = json.loads(commands.getoutput(bash_CV_Info))

	array_CV_Versions=[] # Create an empty array to store CV version ID's in
	for version in json_CV_Info['Versions']:
		array_CV_Versions.append(json_CV_Info['Versions'][version]['ID']) # Store ID's in array

	print 'Obtaining info on: ' + str_CCV_Publish
	bash_CCV_Info = "hammer --output=json content-view info --organization='AU' --name='" + str_CCV_Publish + "'"
	json_CCV_Info = json.loads(commands.getoutput(bash_CCV_Info))

	array_CCV_Components=[] # Create an empty array to store CCV Component ID's in
	for compITEM in json_CCV_Info['Components']:
		array_CCV_Components.append(json_CCV_Info['Components'][compITEM]['ID']) # Store the ID in array

	set_CV_ID = frozenset(array_CV_Versions)
	array_CCV_PubComponents = [] # Setup a location to store the component ID's we are publishing
	for component in array_CCV_Components:
		if component not in set_CV_ID:
			array_CCV_PubComponents.append(component)

	array_CCV_PubComponents.append(max(set_CV_ID)) # Append the newest Version of CV to the Components to deploy


	set_CCV_Comps = ','.join([str(i) for i in array_CCV_PubComponents])
	print 'Updating: ' + str_CCV_Publish + ' with components: ' + set_CCV_Comps
	bash_CCV_Update = "hammer content-view update --organization 'AU' --name '" + str_CCV_Publish + "' --component-ids='" + set_CCV_Comps + "'"
	ret_CCV_Command = commands.getoutput(bash_CCV_Update)
	print 'Complete: ' + ret_CCV_Command
	
	print 'Publishing: ' + str_CCV_Publish
	bash_CCV_Publish = "hammer content-view publish --organization='AU' --name='"+ str_CCV_Publish + "'"
	ret_CCV_Command = commands.getoutput(bash_CCV_Publish)
	print 'Complete: ' + ret_CCV_Command
	# Get CCV Info to find out the newest version number
	json_CCV_Info = json.loads(commands.getoutput(bash_CCV_Info))

	array_CCV_Versions=[] # Create an empty array to store CCV Versions in
	for verITEM in json_CCV_Info['Versions']:
		array_CCV_Versions.append(json_CCV_Info['Versions'][verITEM]['Version']) # Store the ID in array
	CCV_LatestVersion = max(array_CCV_Versions)
	print 'Promoting: ' + ret_CCV_Command + ' Version: ' + CCV_LatestVersion +' To: ' + str_ENV_Promote 
	# Promote to LifeCycle Environment
	bash_CCV_Promote = "hammer content-view version promote --organization='AU' --content-view='" + str_CCV_Publish + "' --to-lifecycle-environment='" + str_ENV_Promote + "' --version='" + CCV_LatestVersion + "' --force"
	ret_CCV_Command = commands.getoutput(bash_CCV_Promote)
	print 'Complete: ' + ret_CCV_Command

if __name__ == "__main__":
	main(sys.argv[1:])
