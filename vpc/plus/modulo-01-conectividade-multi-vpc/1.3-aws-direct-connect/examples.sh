#!/bin/bash

# Criar uma conexão Direct Connect
# Nota: A criação de conexões Direct Connect geralmente envolve um processo físico e não é totalmente automatizável via CLI para a etapa inicial.
# Exemplo de criação de uma Virtual Interface (VIF) privada após a conexão física:
# aws directconnect create-private-virtual-interface --connection-id dxcon-abcdefgh --new-private-virtual-interface-allocation vlan=100,asn=65000,authKey=mykey,amazonAddress=169.254.255.1/30,customerAddress=169.254.255.2/30,virtualInterfaceName=my-private-vif,virtualGatewayId=vgw-0abcdef1234567890
