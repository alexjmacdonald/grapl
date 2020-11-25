const { 
    GraphQLInt, 
    GraphQLString, 
    GraphQLList,
}  = require('graphql');

const expandTo = require('../API/queries/edge.js').expandTo;
const getEdge = require('../API/queries/edge.js').getEdge;
const getEdges = require('../API/queries/edge.js').getEdges;

const getDgraphClient = require('../dgraph_client.js').getDgraphClient;

const lensNodeArgs = () => {
    return {
        lens_name: {type: GraphQLString}, 
        score: {type: GraphQLInt}, 
        lens_type: {type: GraphQLString}, 
    }
}

const lensNodeFilters = (args) => {
    return [
        ['lens_name', args.lens_name, 'string'],
        ['score', args.score, 'int'],
        ['lens_type', args.lens_type, 'string']
    ]
}

module.exports.defaultLensNodesResolver = (edgeName) => {
    const LensNode = require('../node_types/lens_node.js').LensNodeType;

    return {
        type: GraphQLList(LensNode),
        args: lensNodeArgs(),
        resolve: async(parent, args) => {
            console.log("expanding defaultLensNodesResolver");
            const expanded = await expandTo(getDgraphClient(), parent.uid, edgeName, lensNodeFilters(args), getEdges);
            console.log ("expanded defaultLensNodesResolver", expanded);
            return expanded;
        }
    }
};
