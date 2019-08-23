pragma solidity ^0.5.11;

import "./ERC20.sol";
import './SafeMath.sol';

contract LB {
    using SafeMath for uint256;
    address public owner;
    mapping (address => mapping(address => uint256)) public balance;

    uint256 public earthSecondsInMonth = 2629744;
    // uint256 earthSecondsInMonth = 30 * 12 * 60 * 60;


    struct Order{
        address lender;
        address borrow;
        address coin;
        uint256 amount;
        address collateral;
        uint256 collateral_amount;
        uint256 monthly_interest;
        uint8 months;
        uint256 paid;
        uint256 started;
    }

    function mou()public view returns (uint256){
        return now;
    }

    Order[] public orders;

    event NewOrder(
        uint256 indexed _orderNo,
        address indexed _lender,
        address indexed _borrow
    );

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event NewDeposit(
        address indexed _address,
        address indexed _contractAddress,
        uint256 indexed _amount
    );

    event NewWithdraw(
        address indexed _address,
        address indexed _contractAddress,
        uint256 indexed _amount
    );

    event Transfer(
        address indexed _contractAddress,
        address indexed _from,
        address indexed _to,
        uint256 _amount
    );

    event Interest(
        uint256 _order_id,
        uint8 _paid_by_collateral,
        uint256 _amount
    );

    constructor() public {
        owner = msg.sender;
    }

    // Internal transactions function
    // adress(0) is smart contract
    function transfer(address _contractAddress,address _from, address _to,uint256 _amount) internal returns (bool){
        if(balance[_from][_contractAddress] >= _amount){
            require(balance[_from][_contractAddress] >= _amount, "Blanece shold be greater than the amount to be transfered");
            balance[_from][_contractAddress] = balance[_from][_contractAddress].sub(_amount);
            balance[_to][_contractAddress] = balance[_from][_to].add(_amount);
            emit Transfer(_contractAddress, _from, _to, _amount);
            return true;
        }else{
            return false;
        }
    }

    function deposit(address _contractAddress, uint256 _amount) public payable returns (bool) {
        if(_contractAddress != address(0)){
            ERC20 erc20 = ERC20(_contractAddress);
            require(erc20.transferFrom(msg.sender, address(this), _amount));
            balance[msg.sender][_contractAddress] = balance[msg.sender][_contractAddress].add(_amount);
        }else{
            require(msg.value == _amount);
            balance[msg.sender][address(0)] = balance[msg.sender][address(0)].add(_amount);
        }
        emit NewDeposit(msg.sender, address(0), _amount);
        return true;
    }

    /// @notice Withdraw coin from bank
    /// @return The balance remaining for the user
    function withdraw(address _contractAddress, uint256 _amount) public returns (uint256) {
        require(balance[msg.sender][_contractAddress]>= _amount, "Insufficient balance in bank");
        if(_contractAddress == address(0)){
            ERC20 erc20 = ERC20(_contractAddress);
            require(erc20.transfer(msg.sender, _amount));
        }else{
            msg.sender.transfer(_amount);
        }
        balance[msg.sender][_contractAddress] = balance[msg.sender][_contractAddress].sub(_amount);
        emit NewWithdraw(msg.sender, address(0), _amount);
        return balance[msg.sender][_contractAddress];
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function createLend(address _contractAddress, uint256 _amount, address _collateral, uint256 _collateral_amount, uint256 _monthly_interest,uint8 _months) public returns(uint256){
        require(transfer(_contractAddress,msg.sender,address(0),_amount));
        orders.push(Order(msg.sender, address(0), _contractAddress, _amount, _collateral, _collateral_amount, _monthly_interest, _months, 0, 0));
        emit NewOrder(orders.length ,msg.sender, address(0));
        return balance[msg.sender][_contractAddress];
    }

    function createBorrow(address _contractAddress, uint256 _amount, address _collateral, uint256 _collateral_amount, uint256 _monthly_interest,uint8 _months) public returns(uint256){
        require(transfer(_collateral,msg.sender,address(0),_collateral_amount));
        orders.push(Order(address(0), msg.sender, _contractAddress, _amount, _collateral, _collateral_amount, _monthly_interest, _months, 0, 0));
        emit NewOrder(orders.length, address(0) ,msg.sender);
        return balance[msg.sender][_contractAddress];
    }

    function borrow(uint256 _order_id) public {
        Order memory borrow_order = orders[_order_id];
        require(balance[msg.sender][borrow_order.collateral] >= borrow_order.collateral_amount, "Borrower's collateral balance should be greater then order's collateral balance");
        require(transfer(borrow_order.collateral, msg.sender, address(0), borrow_order.amount));
        borrow_order.borrow = msg.sender;
        borrow_order.started = now;
    }

    function lend(uint256 _order_id) public {
        Order memory lend_order = orders[_order_id];
        require(balance[msg.sender][lend_order.coin] >= lend_order.amount, "Lender's amount balance should be greater then order's amount");
        require(transfer(lend_order.coin, msg.sender, address(0), lend_order.amount));
        lend_order.lender = msg.sender;
        lend_order.started = now;
    }

    function claim(uint256 _order_id) public {
        Order memory claim_order = orders[_order_id];
        require(claim_order.lender == msg.sender, "Only lender of the contract can call the function");
        uint256  amount = claim_order.amount.mul(claim_order.monthly_interest).div(100).mul(mou().sub(now)).div(earthSecondsInMonth).sub(claim_order.paid);
        if(transfer(claim_order.coin, claim_order.borrow, claim_order.lender, amount)){
            emit Interest(_order_id,0,amount);
        }else{
            amount = claim_order.collateral_amount.mul(claim_order.monthly_interest).div(100).mul(mou().sub(now)).div(earthSecondsInMonth).sub(claim_order.paid);
            require(transfer(claim_order.collateral, claim_order.borrow, claim_order.lender, amount));
            emit Interest(_order_id,1,amount);
        }
        claim_order.paid = claim_order.paid.add(amount);
    }
}
