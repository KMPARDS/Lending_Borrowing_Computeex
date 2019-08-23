const assert = require('assert');
const ethers = require('ethers');

const ganache = require('ganache-cli');
const provider = new ethers.providers.Web3Provider(ganache.provider({ gasLimit: 8000000 }));

const erc_json = require('../build/EraswapToken_6.json');
const lb_json = require('../build/LB_0.json');

let accounts, erc20_instances = [], lb_instance ="";

describe('Ganache Setup', async() => {
  it('initiates ganache and generates a bunch of demo accounts', async() => {
    accounts = await provider.listAccounts();

    assert.ok(accounts.length >= 2, 'atleast 2 accounts should be present in the array');
  });
});

describe('Era Swap Token', async() => {
  it('deploys ERC20 from first account', async() => {
    const ERCContract = new ethers.ContractFactory(
      erc_json.abi,
      erc_json.evm.bytecode.object,
      provider.getSigner(accounts[0])
    )
    erc20_instances[0] =  await ERCContract.deploy();
    assert.ok(erc20_instances[0].address, 'ERC20 deployed');
  });
  it('Balance greater than zero', async() => {
    assert.ok(String(await erc20_instances[0].functions.balanceOf(accounts[0])), 'Balance');
  });
});

describe('Lend And Borrow Smart Contract', async() => {
  it('Lend and Borrow deploy', async() => {
    const LBContract = new ethers.ContractFactory(
      lb_json.abi,
      lb_json.evm.bytecode.object,
      provider.getSigner(accounts[0])
    )
    lb_instance =  await LBContract.deploy();
    assert.ok(lb_instance.address, 'LB deployed');
  });



  it('Deposit', async() => {
    let amount =  1000000000000;
    await erc20_instances[0].functions.approve(lb_instance.address, amount)
    await lb_instance.functions.deposit(erc20_instances[0].address, amount)
    // console.log(accounts[0])
    // console.log(await lb_instance.functions.balance(accounts[0], erc20_instances[0].address))

  });
});
