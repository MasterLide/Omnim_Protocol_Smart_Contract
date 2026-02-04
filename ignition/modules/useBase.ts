import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import BaseModule from "./deployBase.js"

const threshold    = 100000000000000000000n;
const votingPeriod = 3600;
const stakeAmount  = 50000000000000000000000000n;
const suppyMines   = 200000000000000000000000000n;
const dayMines     = 1000000000000000000000000n;
const decayPerDay  = 5000000000000000000000n;
const mineBase     = 5000;
const mineAddPerDay = 5;

export default buildModule("UseBaseModule", (m) => {
  const deployer = m.getAccount(0);
  const { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactory } = m.useModule(BaseModule);

  m.call(veToken, "initialize", ["VeMainToken","VMT",deployer,mainToken,0n,true]);
  m.call(tokenDAO,"initialize",["TokenDAO",veToken,threshold,votingPeriod]);
  m.call(minerPool,"initialize",[mainToken,veToken,dayMines,decayPerDay,mineBase,mineAddPerDay]);  
  m.call(dataNft,"initialize",[deployer]);
  m.call(tokenFactory,"initialize",[subToken, mainToken, veToken, subToken, dataNft, threshold, deployer]);

  m.call(dataNft,"grantRole",[m.staticCall(dataNft,"MINTER_ROLE"), tokenFactory]);
  m.call(minerPool,"grantRole",[m.staticCall(minerPool,"GOV_ROLE"),deployer]);

  m.call(veToken,"setMiner",[minerPool]);

  m.call(mainToken,"approve",[veToken,stakeAmount]);
  m.call(veToken,"stake",[stakeAmount,deployer,deployer]);
  m.call(mainToken,"mint",[minerPool,suppyMines]);   

  m.call(mainToken,"transferOwnership",[tokenDAO]);

  return { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactory };
});
