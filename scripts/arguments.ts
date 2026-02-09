
import args from "../ignition/modules/arguments.js"

const opAddr = {
    PancakeRouter: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
    DataNft: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    MainToken: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
    MinerPool: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
    SubMinerPool: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
    SubToken: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
    TokenDAO: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    TokenFactoryV2: "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
    VeToken: "0x610178dA211FEF7D417bC0e6FeD39F05609AD788",
    TUSD: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853"
}

const testAddr = {
    PancakeRouter: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    DataNft: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    MainToken: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
    MinerPool: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
    SubMinerPool: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
    SubToken: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
    TokenDAO: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
    TokenFactoryV2: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    VeToken: "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
    TUSD: "0x0165878A594ca255338adfa4d48449f69242Eb8F"
}

const mainAddr = {
    PancakeRouter: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    DataNft: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    MainToken: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
    MinerPool: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
    SubMinerPool: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
    SubToken: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
    TokenDAO: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
    TokenFactoryV2: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    VeToken: "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
    TUSD: "0x0165878A594ca255338adfa4d48449f69242Eb8F"
}

function getAddr(chainId : number){
    switch (chainId){
        case 31337:
            return opAddr;
        case 56:
            return mainAddr;
        case 97:
            return testAddr;
        default:
            return opAddr;
    }
    
}

export default args;

export {opAddr,testAddr,mainAddr,args, getAddr}
