[web_servers]
%{ for instance in instances ~}
${instance.name} ansible_host=${instance.public_ip} ansible_user=ec2-user private_ip=${instance.private_ip} instance_id=${instance.id}
%{ endfor ~}

[web_servers:vars]
ansible_ssh_private_key_file=/path/to/your-key.pem
ansible_python_interpreter=/usr/bin/python3
