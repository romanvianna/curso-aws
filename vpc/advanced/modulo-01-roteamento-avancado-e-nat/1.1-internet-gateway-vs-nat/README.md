# Internet Gateway vs NAT

Um **Internet Gateway (IGW)** permite que instâncias em uma sub-rede pública se conectem à internet. Ele é um componente escalável e redundante que não causa gargalos de largura de banda.

Um **NAT Gateway** (Network Address Translation) permite que instâncias em uma sub-rede privada se conectem à internet ou a outros serviços da AWS, mas impede que a internet inicie uma conexão com essas instâncias. Ele é um serviço gerenciado pela AWS, altamente disponível e escalável.