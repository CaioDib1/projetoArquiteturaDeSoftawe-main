FROM node:14.16.1-alpine3.10 AS base
WORKDIR /var/www/

FROM base AS contact-service
ADD  services/contact/ .
RUN npm install --only=production 
CMD [ "node", "app.js" ]

FROM base AS order-service
ADD  services/order/ .
RUN npm install --only=production 
CMD [ "node", "app.js" ]

FROM base AS shipping-service
ADD  services/shipping/ .
RUN npm install --only=production 
CMD [ "node", "app.js" ]


# ... (conteúdo anterior mantido)

FROM base AS fraud-service
ADD services/fraud-service/ .
RUN npm install --only=production 
CMD [ "node", "app.js" ]

FROM base AS inventory-service
ADD services/inventory-service/ .
RUN npm install --only=production 
CMD [ "node", "app.js" ]

const amqp = require('amqplib');

class RabbitMQService {
    static instance;

    constructor() {
        this.connection = null;
        this.channel = null;
    }

    static async getInstance() {
        if (!this.instance) {
            this.instance = new RabbitMQService();
            await this.instance.init();
        }
        return this.instance;
    }

    async init() {
        this.connection = await amqp.connect('amqp://guest:guest@rabbitmq');
        this.channel = await this.connection.createChannel();
    }

    async send(queue, message) {
        await this.channel.assertQueue(queue, { durable: true });
        this.channel.sendToQueue(queue, Buffer.from(JSON.stringify(message)));
        console.log(`📤 Enviado → ${queue}`);
    }

    async consume(queue, callback) {
        await this.channel.assertQueue(queue, { durable: true });
        console.log(`📥 Aguardando mensagens em ${queue}`);
        this.channel.consume(queue, msg => {
            callback(msg);
            this.channel.ack(msg);
        });
    }
}

module.exports = RabbitMQService;

const RabbitMQ = require('./RabbitMQService');

function isValidOrder(order) {
    return order.name && order.email && order.creditCard && order.address;
}

async function start() {
    const rabbit = await RabbitMQ.getInstance();

    rabbit.consume("orders", async (msg) => {
        const data = JSON.parse(msg.content);

        if (isValidOrder(data)) {
            console.log("✔ Pedido aprovado!");

            await rabbit.send("contact", {
                clientFullName: data.name,
                to: data.email,
                subject: "Pedido aprovado",
                text: `${data.name}, seu pedido foi aprovado!`
            });

            await rabbit.send("shipping", data);
        } else {
            console.log("❌ Pedido inválido!");

            await rabbit.send("contact", {
                clientFullName: data.name,
                to: data.email,
                subject: "Pedido Reprovado",
                text: "Dados insuficientes para completar a compra."
            });
        }
    });
}

start();

const fs = require('fs');
const RabbitMQ = require('./RabbitMQService');

async function start() {
    const rabbit = await RabbitMQ.getInstance();

    rabbit.consume("contact", async (msg) => {
        const mail = JSON.parse(msg.content);

        const filename = `${Date.now()} - ${mail.subject}.txt`;

        fs.writeFileSync(filename, JSON.stringify(mail, null, 2));

        console.log("📨 Email gerado:", filename);
    });
}

start();


const RabbitMQ = require('./RabbitMQService');

async function start() {
    const rabbit = await RabbitMQ.getInstance();

    rabbit.consume("report", async (msg) => {
        const report = JSON.parse(msg.content);

        console.log("📘 RELATÓRIO DE PEDIDO");
        console.log("---------------------------");
        console.log("Cliente:", report.order);
        console.log("Status:", report.status);
        console.log("Endereço:", report.address);
        console.log("---------------------------");
    });
}

start();


