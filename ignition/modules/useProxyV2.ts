import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import BaseV2Module from "./deployBaseV2.js"
import { toHex } from "viem";
import args from "./arguments.js"

export default buildModule("UseProxyV2Module", (m) => {
  const deployer = m.getAccount(0);
  const { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactoryV2,subMinerPool } = m.useModule(BaseV2Module);
  const emptybytes = toHex('');
  
  const veTokenProxy = m.contract("MyProxy",[veToken,deployer,emptybytes],{ id: "veTokenProxy"});
  const veTokenContract = m.contractAt("VeToken",veTokenProxy);

  const tokenDAOProxy = m.contract("MyProxy",[tokenDAO,deployer,emptybytes],{ id: "tokenDAOProxy"});
  const tokenDAOContract = m.contractAt("TokenDAO",tokenDAOProxy);

  const dataNftProxy = m.contract("MyProxy",[dataNft,deployer,emptybytes],{ id: "dataNftProxy"});
  const dataNftContract = m.contractAt("DataNft",dataNftProxy);

  const minerPoolProxy = m.contract("MyProxy",[minerPool,deployer,emptybytes],{ id: "minerPoolProxy"});
  const minerPoolContract = m.contractAt("MinerPool",minerPoolProxy);

  const tokenFactoryProxy = m.contract("MyProxy",[tokenFactoryV2,deployer,emptybytes],{ id: "tokenFactoryV2Proxy"});
  const tokenFactoryContract = m.contractAt("TokenFactoryV2",tokenFactoryProxy);

  m.call(veTokenContract, "initialize", ["VeMainToken","VMT",deployer,mainToken,0n,true]);
  m.call(veTokenContract,"setMiner",[minerPoolProxy]);

  m.call(tokenDAOContract,"initialize",["TokenDAO",veTokenContract,args.threshold,args.votingPeriod]);

  m.call(dataNftContract,"initialize",[deployer]);
  m.call(dataNftContract,"grantRole",[m.staticCall(dataNftContract,"MINTER_ROLE"), tokenFactoryContract]);

  const a = m.call(tokenFactoryContract,"initialize",[subToken, mainToken, veTokenContract, subToken, dataNftContract, args.threshold, deployer]);
  m.call(tokenFactoryContract,"addImplementations",[subToken,veToken,tokenDAO,subMinerPool],{after:[a]});

  m.call(minerPoolContract,"initialize",[mainToken,veTokenContract,args.dayMines,args.decayPerDay,args.mineBase,args.mineAddPerDay]);

  m.call(mainToken,"approve",[veTokenContract,args.stakeAmount]);
  m.call(veTokenContract,"stake",[args.stakeAmount,deployer,deployer]);

  m.call(mainToken,"mint",[minerPoolContract,args.suppyMines]);
  m.call(minerPoolContract,"grantRole",[m.staticCall(minerPoolContract,"GOV_ROLE"),deployer]);
  m.call(mainToken,"transferOwnership",[tokenDAOContract]);

  return { mainToken, veTokenContract, tokenDAOContract, minerPoolContract, dataNftContract, subToken, tokenFactoryContract, subMinerPool};
});
