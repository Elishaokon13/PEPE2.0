// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract PULSEX is IERC20 {
    string public constant name = "Pulsex Token";
    string public constant symbol = "PLX";
    uint8 public constant decimals = 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _blacklist;

    uint256 private _totalSupply;
    uint256 private _buyTaxPercentage = 800; // 8%
    uint256 private _sellTaxPercentage = 1000; // 10%
    address private _owner;
    address private _pancakePair;
    bool public tradingEnabled;

    constructor() {
        _owner = msg.sender;
        _totalSupply = 1000000 * 10**decimals; // Initial supply of 1,000,000 FAB tokens
        _balances[msg.sender] = _totalSupply;
        tradingEnabled = true; // Trading is enabled by default
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyPancakePair() {
        require(msg.sender == _pancakePair, "Only the PancakeSwap pair can perform this action");
        _;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        require(tradingEnabled, "Trading is currently disabled");
        require(!_blacklist[msg.sender], "Sender is blacklisted");
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        require(tradingEnabled, "Trading is currently disabled");
        require(!_blacklist[sender], "Sender is blacklisted");
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function setBlacklist(address account, bool isBlacklisted) external onlyOwner {
        _blacklist[account] = isBlacklisted;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function renounceOwnership() external onlyOwner {
        _owner = address(0);
    }

    function setBuyTaxPercentage(uint256 percentage) external onlyOwner {
        require(percentage <= 1000, "Invalid buy tax percentage"); // Maximum 10% tax allowed
        _buyTaxPercentage = percentage;
    }

    function setSellTaxPercentage(uint256 percentage) external onlyOwner {
        require(percentage <= 1000, "Invalid sell tax percentage"); // Maximum 10% tax allowed
        _sellTaxPercentage = percentage;
    }

    function setPancakePair(address pair) external onlyOwner {
        _pancakePair = pair;
    }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
    }

    function disableTrading() external onlyOwner {
        tradingEnabled = false;
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(_balances[sender] >= amount, "Insufficient balance");

        uint256 taxAmount;

        if (sender == _pancakePair) {
            taxAmount = (amount * _buyTaxPercentage) / 10000; // Calculate buy tax amount
        } else if (recipient == _pancakePair) {
            taxAmount = (amount * _sellTaxPercentage) / 10000; // Calculate sell tax amount
        }

        uint256 transferAmount = amount - taxAmount;

        _balances[sender] -= amount;
        _balances[recipient] += transferAmount;

        emit Transfer(sender, recipient, transferAmount);

        if (taxAmount > 0) {
            _balances[_pancakePair] += taxAmount;
            emit Transfer(sender, _pancakePair, taxAmount);
        }
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burn(address account, uint256 amount) private {
        require(account != address(0), "Burn from the zero address");
        require(amount > 0, "Burn amount must be greater than zero");
        require(_balances[account] >= amount, "Insufficient balance for burn");

        _balances[account] -= amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }
}