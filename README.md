Arquitetura Publish/Subscribe – Exemplo Prático

Matéria: Arquitetura de Software – Prof. Michel
Grupo: Caio Dib

Introdução

("Este projeto apresenta uma implementação prática de uma arquitetura baseada em Publish/Subscribe (Pub/Sub) por meio de uma pequena loja virtual. A proposta é permitir que alunos tenham contato direto com os conceitos fundamentais desse tipo de arquitetura após o estudo do Capítulo 7 do livro Engenharia de Software Moderna.")

A comunicação assíncrona entre os serviços é realizada usando o RabbitMQ, que atua como broker responsável por armazenar, distribuir e gerenciar eventos.

Conceito de Arquitetura Publish/Subscribe

Em arquiteturas tradicionais, o cliente solicita algo e aguarda a resposta síncrona de um serviço.
No modelo Pub/Sub, a comunicação é assíncrona, desacoplada e baseada em eventos:

Produtores publicam eventos.

Consumidores recebem notificações somente dos eventos nos quais estão inscritos.

No contexto de uma loja virtual, o fluxo típico é:

O Checkout publica um evento solicitando o pagamento.

O serviço de pagamento consome esse evento e, após processar, publica outro evento indicando que o pagamento foi aprovado.

Outros serviços (Entrega, Estoque, Nota Fiscal) consomem esse segundo evento.

Estrutura do Sistema

Nosso exemplo simula uma loja de discos de vinil, e o evento principal é a criação de um pedido. Quando um pedido é publicado:

Se válido → notificamos o cliente e enviamos os dados para o setor de despacho.

Se inválido → notificamos o cliente informando que há dados faltantes.

As operações acontecem de forma independente e assíncrona. O cliente não espera que todos os serviços finalizem; ele será notificado posteriormente.

Passo 1 — Configuração e Inicialização do RabbitMQ

O RabbitMQ está disponível em um container Docker incluso no projeto.
Para utilizá-lo:

Certifique-se de ter o Docker instalado.

Na raiz do projeto, execute:

docker-compose up -d q-rabbitmq


A interface do RabbitMQ fica disponível em:
http://localhost:15672

Usuário e senha padrão: guest / guest

Crie uma fila chamada orders com o argumento:
x-queue-mode=lazy
Essa configuração prioriza armazenamento em disco, reduzindo uso de RAM.

Depois disso, é possível publicar um pedido manualmente inserindo um JSON na fila orders.

Passo 2 — Execução dos Serviços do Sistema
Serviço 1 — Envio de Mercadoria (shipping-service)

Esse serviço recebe os dados de entrega e valida se o pedido possui CEP. Se estiver tudo correto, autoriza o despacho.

Trecho principal de processamento:

async function processMessage(msg) {
    const deliveryData = JSON.parse(msg.content)
    try {
        if(deliveryData.address && deliveryData.address.zipCode) {
            console.log(`✔ SUCCESS, SHIPPING AUTHORIZED, SEND TO:`)
            console.log(deliveryData.address)
        } else {
            console.log(`X ERROR, WE CAN'T SEND WITHOUT ZIPCODE :'(`)
        }
    } catch (error) {
        console.log(`X ERROR TO PROCESS: ${error.response}`)
    }
}


Para rodar:

docker-compose up -d --build shipping-service

Serviço 2 — Processamento dos Pedidos (order-service)

Esse serviço é quem consome a fila orders. Ele:

Valida o pedido

Publica mensagens nas filas contact e shipping se estiver tudo certo

Publica apenas na fila contact se o pedido for inválido

Processamento:

async function processMessage(msg) {
    const orderData = JSON.parse(msg.content)
    try {
        if(isValidOrder(orderData)) {
            await (await RabbitMQService.getInstance()).send('contact', { 
                "clientFullName": orderData.name,
                "to": orderData.email,
                "subject": "Pedido Aprovado",
                "text": `${orderData.name}, seu pedido de disco de vinil acaba de ser aprovado, e esta sendo preparado para entrega!`,
            })
            await (await RabbitMQService.getInstance()).send('shipping', orderData)
            console.log(`✔ ORDER APPROVED`)
        } else {
            await (await RabbitMQService.getInstance()).send('contact', { 
                "clientFullName": orderData.name,
                "to": orderData.email,
                "subject": "Pedido Reprovado",
                "text": `${orderData.name}, seus dados não foram suficientes para realizar a compra :( por favor tente novamente!`,
            })
            console.log(`X ORDER REJECTED`)
        }
    } catch (error) {
        console.log(`X ERROR TO PROCESS: ${error.response}`)
    }
}


Executando:

docker-compose up -d --build order-service

Serviço 3 — Envio de E-mail ao Cliente (contact-service)

Esse serviço consome a fila contact e gera arquivos contendo o conteúdo do email (em vez de enviar um e-mail real).

Trecho principal:

async function processMessage(msg) {
    const mailData = JSON.parse(msg.content)
    try {
        const mailOptions = {
            'from': process.env.MAIL_USER,
            'to': `${mailData.clientFullName} <${mailData.to}>`,
            'cc': mailData.cc || null,
            'bcc': mailData.cco || null,
            'subject': mailData.subject,
            'text': mailData.text,
            'attachments': null
        }

        fs.writeFileSync(`${new Date()} - ${mailOptions.subject}.txt`, mailOptions);
        console.log(`✔ SUCCESS`)
    } catch (error) {
        console.log(`X ERROR TO PROCESS: ${error.response}`)
    }
}


Rodando o serviço:

docker-compose up -d --build contact-service

Persistência das Filas

O RabbitMQ está configurado com volumes Docker. Assim, as filas e suas mensagens permanecem salvas mesmo se os containers forem interrompidos.

Para apagar tudo, incluindo dados persistidos:

docker-compose down -v


Para apenas parar:

docker-compose down

Passo 3 — Serviço de Relatório (report-service)

Após um envio ser concluído, uma mensagem é publicada na fila report.
Sua tarefa é criar um serviço que consuma essa fila e imprima informações da venda. Um esqueleto já está disponível em:

/services/report/app.js


Para executar:

docker-compose up -d --build report-service


Ver logs:

docker logs report-service

Envio da Tarefa

Após concluir tudo, faça commit e push:

git add --all
git commit -m "Tarefa prática - Implementação do serviço de relatórios"
git push origin master

Outros Brokers Possíveis

Além do RabbitMQ, outras soluções populares para Pub/Sub incluem:

Apache Kafka

Redis Pub/Sub


3. Diagrama em Texto (Fluxo Completo do Sistema)
                +------------------------+
                |      Cliente           |
                |  (Envia Pedido JSON)   |
                +-----------+------------+
                            |
                            v
                 +----------+-----------+
                 |     Fila: orders     |
                 +----------+-----------+
                            |
                            v
              +-------------+-------------+
              |        orders-service     |
              |  (Valida e encaminha)     |
              +------+------+--------------+
                     |              |
        Pedido válido|              | Pedido inválido
                     |              |
                     v              v
      +--------------+---+    +-----+------------------+
      | Fila: shipping  |    | Fila: contact          |
      +---------+--------+    +-----------+------------+
                |                         |
                v                         v
     +----------+----------+    +---------+-----------+
     |    shipping-service |    |   contact-service  |
     | (Autoriza entrega)  |    | (Gera “email”)     |
     +----------+----------+    +---------+-----------+
                |                         |
                |                         |
                v                         |
        +-------+--------+                |
        | Fila: report   | <--------------+
        +-------+--------+
                |
                v
     +----------+------------+
     |    report-service     |
     | (Exibe resumo venda)  |
     +------------------------+

//Subir o RabbitMQ

docker-compose up -d q-rabbitmq


Criar fila orders com x-queue-mode=lazy.

Publicar um pedido JSON na fila.

Subir os serviços:

docker-compose up -d --build shipping-service
docker-compose up -d --build order-service
docker-compose up -d --build contact-service
docker-compose up -d --build report-service


Ver logs:

docker logs <serviço>

5. Persistência

RabbitMQ usa volumes → mensagens não se perdem.
Remover tudo:

docker-compose down -v

6. Entrega no GitHub
git add --all
git commit -m "Tarefa prática - relatório"
git push origin master






