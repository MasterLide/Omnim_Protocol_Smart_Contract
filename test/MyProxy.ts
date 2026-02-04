import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { toHex } from "viem";


describe("MyProxy", async function () {
  const { viem } = await network.connect();
  const [senderClient, test] = await viem.getWalletClients();

  it("Should able to Proxy and upgrade ", async function () {
    const contract1 = await viem.deployContract("MinerPool");
    const contract2 = await viem.deployContract("SubMinerPool");
    const a = toHex('');

    const myProxy = await viem.deployContract("MyProxy",[contract1.address,senderClient.account.address,a]);
    const logic1 = await viem.getContractAt("MinerPool",myProxy.address);
    assert.equal(30, await logic1.read.LOOP_LIMIT());

    const adminProxy = await viem.getContractAt("ProxyAdmin",await myProxy.read.getProxyAdmin());
    await adminProxy.write.upgradeAndCall([myProxy.address,contract2.address,a]);
    assert.equal(100, await logic1.read.LOOP_LIMIT());

  });
});
