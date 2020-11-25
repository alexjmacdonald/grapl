const dgraph = require("dgraph-js");
const grpc = require("grpc");

const get_random = (list) => {
    return list[Math.floor((Math.random()*list.length))];
}

const mg_alpha = get_random(process.env.MG_ALPHAS.split(","));

client = null;

module.exports.getDgraphClient = (init_client=false) => {
    if (init_client || !client) {
        const clientStub = new dgraph.DgraphClientStub(
            // addr: optional, default: "localhost:9080"
            mg_alpha,
            // credentials: optional, default: grpc.credentials.createInsecure()
            grpc.credentials.createInsecure(),
        );

        client = new dgraph.DgraphClient(clientStub)
    }

    return client;
}
