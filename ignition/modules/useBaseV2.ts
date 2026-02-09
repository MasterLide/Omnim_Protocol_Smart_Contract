import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import BaseV2Module from "./deployBaseV2.js"
import args from "./arguments.js"

export default buildModule("UseBaseV2Module", (m) => {
  const deployer = m.getAccount(0);
  const { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactoryV2, subMinerPool } = m.useModule(BaseV2Module);

  m.call(veToken, "initialize", ["VeMainToken","VMT",deployer,mainToken,0n,true]);
  m.call(tokenDAO,"initialize",["TokenDAO",veToken,args.threshold,args.votingPeriod]);
  m.call(minerPool,"initialize",[mainToken,veToken,args.dayMines,args.decayPerDay,args.mineBase,args.mineAddPerDay]);  
  m.call(dataNft,"initialize",[deployer]);

  const a = m.call(tokenFactoryV2,"initialize",[subToken, mainToken, veToken, subToken, dataNft, args.threshold, deployer])

  m.call(tokenFactoryV2,"addImplementations",[subToken,veToken,tokenDAO,subMinerPool],{after:[a]});

  m.call(dataNft,"grantRole",[m.staticCall(dataNft,"MINTER_ROLE"), tokenFactoryV2]);
  m.call(minerPool,"grantRole",[m.staticCall(minerPool,"GOV_ROLE"),deployer]);

  m.call(veToken,"setMiner",[minerPool]);

  m.call(mainToken,"approve",[veToken,args.stakeAmount]);
  m.call(veToken,"stake",[args.stakeAmount,deployer,deployer]);
  m.call(mainToken,"mint",[minerPool,args.suppyMines]);   
  
  m.call(mainToken,"transferOwnership",[tokenDAO]);

  return { mainToken, veToken, tokenDAO, minerPool, dataNft, subToken, tokenFactoryV2, subMinerPool };
});
