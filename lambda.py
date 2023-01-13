import boto3

client = boto3.client('route53resolver')

def lambda_handler(event, context):
    if event['firewall_rule_action'] == 'BLOCK':
        if event['answers'].length > 0:
           cnames = []
           for answer in event['answers']:
               if answer['Type'] == 'CNAME':
                   cnames += [answers['Rdata']]

           if cnames.length > 0:
               client.update_firewall_domains(
                 FirewallDomainListId=event['firewall_domain_list_id'],
                 Operation='ADD',
                 Domains=[
                   event['answers'][*]['Rdata']
                 ]
               )


# if firewall_rule_action is BLOCK and answers.length > 0
# add answers of type CNAME to the whitelist

