// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../../interfaces/IERC20Detailed.sol";
import "../../interfaces/IPriceable.sol";
import "../../interfaces/IPriceOracle.sol";

/**
 * @dev Mock ERC20 + IPriceable usado para o TokenSale. `convertTo` retorna uma
 *      taxa fixa (1 token = 1 ETH na base 10^18) e o transferFrom não exige
 *      allowance (só saldo), o suficiente para exercitar o fluxo de investimento.
 */
contract MockSaleToken is IERC20Detailed, IPriceable {
    string private _name = "MockSaleToken";
    string private _symbol = "MST";
    uint8 private _decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    IPriceOracle public override priceOracle;

    function name() external override view returns (string memory) { return _name; }
    function symbol() external override view returns (string memory) { return _symbol; }
    function decimals() external override view returns (uint8) { return _decimals; }
    function totalSupply() external override view returns (uint256) { return _totalSupply; }
    function balanceOf(address who) external override view returns (uint256) { return _balances[who]; }
    function allowance(address owner, address spender) external override view returns (uint256) { return _allowances[owner][spender]; }

    function transfer(address to, uint256 value) external override returns (bool) {
        _move(msg.sender, to, value);
        return true;
    }
    function approve(address spender, uint256 value) external override returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        // sem checagem de allowance (mock) — só saldo
        _move(from, to, value);
        return true;
    }

    function setPriceOracle(IPriceOracle) external override {}

    function convertTo(uint256, string calldata, uint8) external override view returns (uint256) {
        return 10**18; // taxa fixa: 1 token por 1 ETH (base 10^18)
    }

    function mint(address to, uint256 amount) external {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _move(address from, address to, uint256 value) internal {
        require(_balances[from] >= value, "insufficient balance");
        _balances[from] -= value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }
}
