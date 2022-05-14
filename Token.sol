// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
import "./SafeMath.sol";
import "./Uniswap.sol";
import "./ERC20.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./Uniswap.sol";
contract Token is Ownable, ERC20,ReentrancyGuard {
    using SafeMath for uint256;
    address public growthFundAddress;
    uint256 public feeRate = 10;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) bots;
    bool public blacklistEnabled;
    uint256 public blacklistDuration = 10 minutes;
    uint256 public blacklistTime;
    uint256 public blacklistAmount;
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    constructor() ERC20("Save Luna Token", "SLN") {
        growthFundAddress = _msgSender();
        uniswapV2Router = IUniswapV2Router02(
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        );
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
        .createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), ~uint256(0));
        _isExcludedFromFees[_msgSender()]=true;
        _mint(_msgSender(), 10*10**9*10**18);
    }
   
    function setGrowthFundAddress(address _address) public onlyOwner {
        growthFundAddress = _address;
    }
    
    function swapTokenForGrowthFund() public nonReentrant {
        uint256 contractTokenBalance = balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            contractTokenBalance,
            0,
            path,
            growthFundAddress,
            block.timestamp
        );
    }
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Account is already 'excluded'");
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }
      function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }
     function setBlacklists(address _bots) external onlyOwner {
        require(!bots[_bots]);
        require(_bots!=uniswapV2Pair,"pair address can not be pair");
        bots[_bots] = true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (blacklistEnabled &&(amount > blacklistAmount || bots[sender] )) {
            revert("You're bot");
        }
        if (sender != address(this) && recipient != address(this) && !_isExcludedFromFees[sender] && !_isExcludedFromFees[recipient]) {
            if(sender==uniswapV2Pair||recipient==uniswapV2Pair){
                uint256 _fee = amount.mul(feeRate).div(100);
                super._transfer(sender,address(this), _fee);
                super._transfer(address(this), 0x0000000000000000000000000000000000000000, _fee/2);
                swapAndLiquify(_fee/5);
                swapTokensForEth(_fee*3/10,growthFundAddress);
                amount = amount.sub(_fee);
            }
        }
        super._transfer(sender, recipient, amount);
    }
    function blacklist(uint256 amount) external onlyOwner {
        require(amount > 0, "amount > 0");
        require(!blacklistEnabled);
        blacklistAmount = amount;
        blacklistEnabled = true;
    }
    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens/2;
        uint256 otherHalf = tokens-half;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half,address(this));
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

  function swapTokensForEth(uint256 tokenAmount,address _to) private {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0,
      path,
      _to,
      block.timestamp
    );
  }
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      0,
      0,
      address(0),
      block.timestamp
    );
  }
}