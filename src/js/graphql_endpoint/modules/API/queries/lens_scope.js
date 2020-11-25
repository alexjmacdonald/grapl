const getDgraphClient = require('../../dgraph_client.js').getDgraphClient;
const getLensByName = require('./lenses').getLensByName;
const inLensScope = require('./lenses').inLensScope;
const getNeighborsFromNode = require('./node.js').getNeighborsFromNode;
const getRisksFromNode = require('./node.js').getRisksFromNode;
const builtins = require('../../node_types/grapl_entity.js').builtins;

module.exports.handleLensScope = async (parent, args) => {
    const dg_client = getDgraphClient();

    const lens_name = args.lens_name;

    const lens = await getLensByName(dg_client, lens_name);

    lens["scope"] = lens["scope"] || [];
    console.log(lens)

    for (const node of lens["scope"]) {
        node.dgraph_type = node.dgraph_type.filter((t) => (t !== 'Base' && t !== 'Entity'))

        // node.uid = parseInt(node.uid, 16);
        if(!node.dgraph_type){
            console.warn("No DGraph Type", node)
        }
        // for every node in our lens scope, get its neighbors

        const nodeEdges = await getNeighborsFromNode(dg_client, node["uid"]);

        for (const maybeNeighborProp in nodeEdges) {
            const maybeNeighbor = nodeEdges[maybeNeighborProp];
            // maybeNeighbor.uid = parseInt(maybeNeighbor.uid, 16);
            
            // A neighbor is either an array of objects with uid fields
            if (Array.isArray(maybeNeighbor) && maybeNeighbor && maybeNeighbor[0].uid) {
                const neighbors = maybeNeighbor;

                for (const neighbor of neighbors) {
                    if (!neighbor.dgraph_type) {continue}
                    neighbor.dgraph_type = neighbor.dgraph_type.filter((t) => (t !== 'Base' && t !== 'Entity'))

                    const isInScope = await inLensScope(dg_client, neighbor["uid"], lens["uid"]);
                    neighbor.uid = parseInt(neighbor.uid, 16);
                    if (isInScope) {
                        if (Array.isArray(node[maybeNeighborProp])) {
                            node[maybeNeighborProp].push(neighbor);
                        } else {
                            node[maybeNeighborProp] = [neighbor];
                        }
                    }
                }
            }
            else if (typeof maybeNeighbor === 'object' && maybeNeighbor.uid) {
                const neighbor = maybeNeighbor;
                neighbor.dgraph_type = neighbor.dgraph_type.filter((t) => (t !== 'Base' && t !== 'Entity'))

                const isInScope = await inLensScope(dg_client, neighbor["uid"], lens["uid"]);
                neighbor.uid = parseInt(neighbor.uid, 16);
                if (isInScope) {
                    if(!builtins.has(neighbor.dgraph_type[0])) {
                        const tmpNode = {...neighbor};
                        // Object.keys(node).forEach(function(key) { delete node[key]; });
                        neighbor.predicates = tmpNode;
                    }
                    node[maybeNeighborProp] = neighbor
                }
            }
        }
    }

    for (const node of lens["scope"]) {
        node.dgraph_type = node.dgraph_type.filter((t) => (t !== 'Base' && t !== 'Entity'))

        try {
            let nodeUid = node['uid'];
            if (typeof nodeUid === 'number') {
                nodeUid = '0x' + nodeUid.toString(16)
            }
            const risks = await getRisksFromNode(dg_client, nodeUid);
            if (risks) {
                for (const risk of risks) {
                    risk['dgraph_type'] = risk['dgraph_type'].filter((t) => (t !== 'Base' && t !== 'Entity'))

                    risk['uid'] = parseInt(risk['uid'], 16)
                }
                node['risks'] = risks;
            }
        } catch (err) {
            console.error('Failed to get risks', err);
        }
        node.uid = parseInt(node.uid, 16);
        // If it's a plugin we want to store the properties in a wrapper
        console.log("Node", node)
        if(!builtins.has(node.dgraph_type[0])) {
            const tmpNode = {...node};
            node.predicates = tmpNode;
        }
    }

    for (const node of lens["scope"]) {
        node.dgraph_type = node.dgraph_type.filter((t) => (t !== 'Base' && t !== 'Entity'))
    }

    lens.uid = parseInt(lens.uid, 16);
    return lens

}
