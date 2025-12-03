Arquitetura Publish/Subscribe – Exemplo Prático

Matéria: Arquitetura de Software – Prof. Michel
Aluno: Caio Dib

 Descrição

Este projeto implementa uma loja virtual de discos de vinil usando arquitetura Publish/Subscribe com RabbitMQ.
O objetivo é demonstrar:

Comunicação assíncrona entre serviços

Desacoplamento entre produtores e consumidores

Tolerância a falhas e persistência de mensagens

 Diagrama de Arquitetura (texto)
   [Cliente faz pedido] 
            │
            ▼
        [orders] ---Publishes--► order-service
            │                          │
            │                          ▼
            │                    - Valida pedido
            │                    - Envia para filas:
            │                        contact
            │                        shipping
            ▼
    [contact-service]               [shipping-service]
        │                                │
        ▼                                ▼
    Gera email                     Prepara envio
                                    │
                                    ▼
                                 [report-service]
                                    │
                                    ▼
                             Gera relatório

🛠 Serviços
Serviço	Função
order-service	Recebe pedidos, valida, envia para filas contact e shipping
shipping-service	Processa envio, publica evento na fila report
contact-service	Gera arquivo de e-mail para o cliente
report-service	Consome fila report e exibe relatório de pedidos
 Como Rodar

Subir RabbitMQ e serviços:

docker-compose up -d --build


Ver logs de cada serviço (exemplo order-service):

docker logs order-service


Inserir um pedido manualmente na fila orders via RabbitMQ Management:

{
  "name": "Caio Dib",
  "email": "caio@email.com",
  "cpf": "12345678900",
  "creditCard": {
    "number": "1234123412341234",
    "securityNumber": "123"
  },
  "products": [
    {"name": "Vinil Rock", "value": 150}
  ],
  "address": {
    "zipCode": "12345-678",
    "street": "Rua Exemplo",
    "number": "100",
    "neighborhood": "Centro",
    "city": "Belo Horizonte",
    "state": "MG"
  }
}

 Características

Desacoplamento: serviços independentes

Assíncrono: cliente não espera processamento completo

Tolerante a falhas: mensagens permanecem na fila se o serviço estiver offline

Persistência: dados salvos via volume Docker (rabbitmq_data)

🔗 Tecnologias

Node.js – implementação dos serviços

RabbitMQ – broker Pub/Sub

Docker & Docker Compose – conteinerização

fs – para geração de arquivos de e-mail (simulação)

 Comandos Úteis

Subir todos os serviços:

docker-compose up -d --build


Parar serviços mantendo dados:

docker-compose down


Parar serviços e remover volumes:

docker-compose down -v


Logs de serviço:

docker logs <nome-do-serviço>

 Próximos Passos

Implementar envio real de e-mails

Criar interface web para monitoramento de pedidos

Testar falhas e reinício de serviços para validar tolerância

 Licença

Código: MIT

Roteiro e tutorial: CC-BY