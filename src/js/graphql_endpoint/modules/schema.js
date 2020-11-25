const getDgraphClient = require('./dgraph_client.js').getDgraphClient;
const getLenses = require('./API/queries/lenses.js').getLenses;
const getLensScope = require('./API/queries/lens_scope.js').getLensScope;
const getNode = require('./API/queries/node.js').getNode;

const LensWithErrors = require('../modules/API/error_types.js').LensWithErrors;
const LensScopeWithErrors = require('../modules/API/error_types.js').LensScopeWithErrors;
const ProcessWithErrors = require('../modules/API/error_types.js').ProcessWithErrors;

const { 
    GraphQLObjectType, 
    GraphQLInt, 
    GraphQLString, 
    GraphQLNonNull,
    GraphQLSchema
}  = require('graphql');

const RootQuery = new GraphQLObjectType({
    name: 'RootQueryType', 
    fields: () => {
        return {
            lenses: {
                type: LensWithErrors, 
                args: {
                    first: {
                        type: new GraphQLNonNull(GraphQLInt)
                    },
                    offset: {
                        type: new GraphQLNonNull(GraphQLInt)
                    }
                },
                resolve: async (parent, args) => {
                    const first = args.first;
                    const offset = args.offset; 
                    // #TODO: Make sure to validate that 'first' is under a specific limit, maybe 1000
                    try {
                        const lenses =  await getLenses(getDgraphClient(), first, offset);
                        console.log('lenses', lenses);
                        return {lenses};
                    } catch (e) {
                        console.log("Error: Lenses Query Failed ", e);
                        return errMsgs(500, 'Lenses')
                    }
                    
                } 
            },
            lens_scope:{
                type: LensScopeWithErrors,
                args: {
                    lens_name: {type: new GraphQLNonNull(GraphQLString)}
                },
                resolve: async (parent, args) => {
                    try {
                        console.log("getLensScope")
                        return await getLensScope(parent, args);
                    } catch (e) { 
                        console.log("Error: Lens Scope Query Failed ", e);
                        return errMsgs(500, 'Lens Scope'); 
                    }
                }
            },
            process:  {
                type: ProcessWithErrors,
                args: {
                    process_id: {type: GraphQLInt}, 
                    process_name: {type: GraphQLString}
                }, 
                resolve: async (parent, args) => {
                    try{
                        const process = await getNode(
                            getDgraphClient(), 
                            'Process',
                            [
                                ['process_id', args.process_id, 'int'],
                                ['process_name', args.process_name, 'string'],
                            ]
                        ); 
                        console.log("Process Found ", process)
                        return process; 
                    } catch (e) {
                        console.log("Error: Process Query Failed ", e);
                        return {
                            error_message: "Process query failed"
                        };
                    }   
                }
            }
        }
    }
})

module.exports = new GraphQLSchema({
    query: RootQuery
});
