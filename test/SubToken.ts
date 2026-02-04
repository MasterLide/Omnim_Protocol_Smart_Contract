import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { encodeFunctionData } from "viem";

describe("SubToken", async function () {
  const { viem } = await network.connect();
  const [senderClient, test] = await viem.getWalletClients();

  it("Should able to  mint()/executeOperations()/burn() ", async function () {
    const subToken = await viem.deployContract("SubToken");
    await subToken.write.initialize(["SubToken","SBT",18,20000000000000000000n,1000000000000000000n,senderClient.account.address]);
    await subToken.write.mint([subToken.address, 2000000000000000000n]);
    assert.equal(2000000000000000000n, await subToken.read.balanceOf([subToken.address]));

    const cd = encodeFunctionData({abi:subToken.abi,functionName: "transfer",args: [test.account.address,2000000000000000000n]});
    await subToken.write.executeOperations([subToken.address,0n,cd]);
    assert.equal(2000000000000000000n, await subToken.read.balanceOf([test.account.address]));
    assert.equal(0n, await subToken.read.balanceOf([subToken.address]));

    await test.writeContract({
        address: subToken.address,
        abi:subToken.abi,
        functionName: 'burn',
        args: [1000000000000000000n],
      });

    assert.equal(1000000000000000000n, await subToken.read.balanceOf([test.account.address]));
  });
});
