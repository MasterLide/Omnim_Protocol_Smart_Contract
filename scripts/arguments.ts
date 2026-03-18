
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

const fluxTestAddr = {
    PancakeRouter: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    DataNft: "0x295Eec078886CFBf44e96B2A3Bf08680De28DFF3",
    MainToken: "0x85A5244d434211a27744e4076Ff34CD88a793FaE",
    MinerPool: "0x5A94A4AB54Fd983E7b9dCa85D9792d2D758640A1",
    SubMinerPool: "0x7d6a406376EA33c904F40bc23dE611cd222bd8c0",
    SubToken: "0x0884C4f2F4342DDF62A7b96E1145C93065c816af",
    TokenDAO: "0x522E96727d7e7e87Ef2aceFfFA7950aA76a633A7",
    TokenFactoryV2: "0xbE45EB71B2fC2Bc9D53451C3a94169FeEEF3cb31",
    VeToken: "0xedF4AfBF6eE78fbe2fF748A3bCf6917f3A22a9e3",
    TUSD: "0x0884C4f2F4342DDF62A7b96E1145C93065c816af"
}

function getAddr(chainId : number){
    switch (chainId){
        case 31337:
            return opAddr;
        case 56:
            return mainAddr;
        case 71:
            return fluxTestAddr;
        case 97:
            return testAddr;
        default:
            return opAddr;
    }
    
}

export default args;

export {opAddr,testAddr,mainAddr,args, getAddr}
