import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("SubMinerPool", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const testClient = await viem.getTestClient();
  const [senderClient, test] = await viem.getWalletClients();

    const mainToken = await viem.deployContract("MainToken",[100000n,senderClient.account.address]);

    const veToken = await viem.deployContract("VeToken");
    await veToken.write.initialize(["VeToken","VTK",senderClient.account.address,mainToken.address,0n,true]);

    const minerPool = await viem.deployContract("MinerPool");
    await minerPool.write.initialize([mainToken.address,veToken.address,100000n,5000n,5000,50]);
    await veToken.write.setMiner([minerPool.address]);

    await mainToken.write.approve([veToken.address,200n]);
    await veToken.write.stake([200n,senderClient.account.address,test.account.address]);
    await mainToken.write.mint([minerPool.address,100000000n]);
    await minerPool.write.grantRole([await minerPool.read.GOV_ROLE(),senderClient.account.address]);
    await minerPool.write.openMine();

    const subToken = await viem.deployContract("SubToken");
    await subToken.write.initialize(["SubToken","SBT",18,20000000000000000000n,senderClient.account.address]);

    const subVeToken = await viem.deployContract("VeToken");
    await subVeToken.write.initialize(["SubVeToken","SVT",senderClient.account.address,subToken.address,0n,true]);

    const subMinerPool = await viem.deployContract("SubMinerPool");
    await subMinerPool.write.initialize([mainToken.address,subVeToken.address,minerPool.address]); 
    await subVeToken.write.setMiner([subMinerPool.address]);

    await mainToken.write.approve([veToken.address,200n]);
    await veToken.write.stake([200n,subMinerPool.address,subMinerPool.address]);
    
    await subToken.write.mint([test.account.address,100000n]);
    await test.writeContract({
        address: subToken.address,
        abi:subToken.abi,
        functionName: 'approve',
        args: [subVeToken.address,2000n],
    });

    await test.writeContract({
        address: subVeToken.address,
        abi:subVeToken.abi,
        functionName: 'stake',
        args: [2000n,test.account.address,test.account.address],
    });
    

  it("Should able to mint/claim and auto mint on minerPool", async function () {
    const [claim, nums] = await minerPool.read.getTotalClaimableMines([senderClient.account.address]);

    assert.equal(50000n, claim);
    assert.equal(1n, nums);

    await testClient.request({method:"evm_increaseTime",params:[`0x15180`]});

    await minerPool.write.claimMyMines([senderClient.account.address]);

    const [claim2, nums2] = await minerPool.read.getTotalClaimableMines([senderClient.account.address]);
    assert.equal(0n, claim2);
    assert.equal(2n, nums2);
    //day1 = 100000 * 5000 / 10000 = 50000
    //day2 = (100000 - 5000) * (5000 + 50) / 10000 * (200/400) = 47975 / 2 = 23987.5 = 23987
    //100000 - 200 - 200 + 50000 + 23987 = 149600 + 23987 = 173587
    assert.equal(173587n, await mainToken.read.balanceOf([senderClient.account.address]));

    await testClient.request({method:"evm_increaseTime",params:[`0x15180`]});

    await minerPool.write.doMine();

    const [claim3, nums3] = await minerPool.read.getTotalClaimableMines([senderClient.account.address]);
    //day3 = (100000 - 10000) * (5000 + 100) / 10000 * (200/400) = 45900 / 2 = 22950
    assert.equal(22950n, claim3);
    assert.equal(3n, nums3);


  });

  it("Should able to mint/claim and auto mint with subMinerPool", async function () {
    const [claim, nums] = await subMinerPool.read.getClaimableMines([test.account.address]);

    assert.equal(0n, claim);
    assert.equal(0n, nums);

    const [claim2, nums2] = await minerPool.read.getTotalClaimableMines([subMinerPool.address]);
    //day1 = 0
    //day2 = (100000 - 5000) * 5000  / 10000 * (200/400) = 95000 / 4 = 23750 
    //day3 = (100000 - 10000) * (5000 + 50) / 10000 * (200/400) = 9 * 2525 = 22725   
    //23750 + 22725 = 46475
    assert.equal(46475n, claim2);
    assert.equal(3n, nums2);

    await testClient.request({method:"evm_increaseTime",params:[`0x15180`]});

    await test.writeContract({
        address: subMinerPool.address,
        abi:subMinerPool.abi,
        functionName: 'claimMyMines',
        args: [test.account.address],
    });

    const [claim3, nums3] = await minerPool.read.getTotalClaimableMines([subMinerPool.address]);
    assert.equal(0n, claim3);
    assert.equal(4n, nums3);
    //day4 = (100000 - 15000) * (5000 + 100) / 10000 * (200/400) = 85000 * 0.255 = 21675   
    //46475 + 21675 = 68150
    assert.equal(68150n, await mainToken.read.balanceOf([test.account.address]));

    const [claim4, nums4] = await minerPool.read.getTotalClaimableMines([senderClient.account.address]);
    //day4 = (100000 - 15000) * (5000 + 150) / 10000 * (200/400) = 85000 * 0.2575 = 21887.5 =  21887
    //22950 + 21887 = 44837
    assert.equal(44837n, claim4);
    assert.equal(4n, nums4);

  });
});
