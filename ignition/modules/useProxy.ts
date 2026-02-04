import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import BaseModule from "./deployBase.js"
import { toHex } from "viem";

const threshold    = 100000000000000000000n;
const votingPeriod = 3600;
const stakeAmount  = 50000000000000000000000000n;
const suppyMines   = 200000000000000000000000000n;
const dayMines     = 1000000000000000000000000n;
const decayPerDay  = 5000000000000000000000n;
const mineBase     = 5000;
const mineAddPerDay = 5;

export default buildModule("UseProxyModule", (m) => {
  const deployer = m.getAccount(0);
  const { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactory } = m.useModule(BaseModule);
  const emptybytes = toHex('');
  
  const veTokenProxy = m.contract("MyProxy",[veToken,deployer,emptybytes],{ id: "Proxy1"});
  const veTokenContract = m.contractAt("VeToken",veTokenProxy);

  const tokenDAOProxy = m.contract("MyProxy",[tokenDAO,deployer,emptybytes],{ id: "Proxy2"});
  const tokenDAOContract = m.contractAt("TokenDAO",tokenDAOProxy);

  const dataNftProxy = m.contract("MyProxy",[dataNft,deployer,emptybytes],{ id: "Proxy3"});
  const dataNftContract = m.contractAt("DataNft",dataNftProxy);

  const minerPoolProxy = m.contract("MyProxy",[minerPool,deployer,emptybytes],{ id: "Proxy4"});
  const minerPoolContract = m.contractAt("MinerPool",minerPoolProxy);

  const tokenFactoryProxy = m.contract("MyProxy",[tokenFactory,deployer,emptybytes],{ id: "Proxy5"});
  const tokenFactoryContract = m.contractAt("TokenFactory",tokenFactoryProxy);

  m.call(veTokenContract, "initialize", ["VeMainToken","VMT",deployer,mainToken,0n,true]);
  m.call(veTokenContract,"setMiner",[minerPoolProxy]);

  m.call(tokenDAOContract,"initialize",["TokenDAO",veTokenContract,threshold,votingPeriod]);

  m.call(dataNftContract,"initialize",[deployer]);
  m.call(dataNftContract,"grantRole",[m.staticCall(dataNftContract,"MINTER_ROLE"), tokenFactoryContract]);

  m.call(tokenFactoryContract,"initialize",[subToken, mainToken, veTokenContract, subToken, dataNftContract, threshold, deployer]);

  m.call(minerPoolContract,"initialize",[mainToken,veTokenContract,dayMines,decayPerDay,mineBase,mineAddPerDay]);

  m.call(mainToken,"approve",[veTokenContract,stakeAmount]);
  m.call(veTokenContract,"stake",[stakeAmount,deployer,deployer]);

  m.call(mainToken,"mint",[minerPoolContract,suppyMines]);
  m.call(minerPoolContract,"grantRole",[m.staticCall(minerPoolContract,"GOV_ROLE"),deployer]);
  m.call(mainToken,"transferOwnership",[tokenDAOContract]);

  return { mainToken, veTokenContract, tokenDAOContract, minerPoolContract, dataNftContract, subToken, tokenFactoryContract };
});
