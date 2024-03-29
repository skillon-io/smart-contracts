// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../abstract/ManagerAccess.sol";
import "../abstract/DepositWithdraw.sol";
import "../interfaces/dex/IRouter02.sol";
import "../interfaces/dex/IPair02.sol";
import "../interfaces/dex/IFactory02.sol";

contract TokenDistributionManager is Context, Ownable, ManagerAccess, DepositWithdraw {
    using SafeERC20 for IERC20;
    uint256 constant MAX_INT = 2 ** 256 - 1;

    // address of the ERC20 token
    IERC20 public immutable token;
    // address of swap router
    IRouter02 public swapRouter;

    uint256 public totalSystemCommissionAmount;
    uint256 public totalAirdropAmount;
    uint256 public totalLiquidityAmount;

    // Liquidity insert threshold
    uint256 public liquidityInsertThreshold;
    // Add liquidity slippage (100 -> %10)
    uint16 public liquiditySlippage = 100;
    // Liquidity pool
    IPair02 public liquidityPool;

    address public airdropReceiver;
    address public feeReceiver;

    // System fee ratio %66.4
    uint16 public systemTransferRatio = 664;
    // Airdrop ratio %13.4
    uint16 public airdropRatio = 134;
    // Liquidity ratio %20.2
    uint16 public liquidityRatio = 202;

    event AirdropReceiverUpdated(address receiver);
    event FeeReceiverUpdated(address receiver);
    event AllowanceUpdated(address token, address spender, uint amount);
    event LiquiditySlippageUpdated(uint16 slippage);
    event LiquidityInsertThresholdUpdated(uint threshold);
    event TokenSold(uint amount);
    event AddLiquidity(uint tokenAmount, uint ethAmount, uint lpTokenAmount);
    event DistributionFailed(uint distributeAmount, uint balance);

    constructor(address token_){
        // Check that the token address is not 0x0.
        require(token_ != address(0x0));
        // Set the token address.
        token = IERC20(token_);
        // Set airdrop receiver
        airdropReceiver = _msgSender();
        // Set system fee receiver
        feeReceiver = _msgSender();
    }

    function setSwapRouter(address swapRouter_) public onlyOwner {
        require(swapRouter_ != address(0), "Router cant be zero address");
        // Set swap router
        swapRouter = IRouter02(swapRouter_);
        // Set LP pair
        liquidityPool = IPair02(IFactory02(swapRouter.factory()).getPair(swapRouter.WETH(), address(token)));
    }

    function setAllowance(address tokenAddress, address spender, uint allowanceAmount) public onlyOwnerOrManager {
        require(spender != address(0), "Spender cant be zero address");
        require(tokenAddress != address(0), "Token address cant be zero address");
        IERC20 token_ = IERC20(tokenAddress);
        token_.approve(spender, allowanceAmount);
        emit AllowanceUpdated(tokenAddress, spender, allowanceAmount);
    }

    function setLiquiditySlippage(uint16 slippage) public onlyOwnerOrManager {
        require(slippage >= 0 && slippage <= 1000, "Slippage not correct");
        liquiditySlippage = slippage;
        emit LiquiditySlippageUpdated(slippage);
    }

    function setLiquidityInsertThreshold(uint threshold) public onlyOwnerOrManager {
        liquidityInsertThreshold = threshold;
        emit LiquidityInsertThresholdUpdated(threshold);
    }

    function _thousandRatio(uint value, uint16 ratio) internal pure returns (uint, uint) {
        require(ratio < 1000, "Ratio: Ratio should lower than thousand");
        uint piece = value * ratio / 1000;
        return (piece, value - piece);
    }

    function _min(uint a, uint b) internal pure returns (uint) {
        return (a < b ? a : b);
    }

    function _max(uint a, uint b) internal pure returns (uint) {
        return (a > b ? a : b);
    }

    function _swapTokensForETH(uint swapAmount) internal returns (bool) {
        bool swapCompleted = false;
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = swapRouter.WETH();

        try swapRouter.swapExactTokensForETH(swapAmount, 0, path, address(this), block.timestamp) {
            swapCompleted = true;
            emit TokenSold(swapAmount);
        } catch {
            swapCompleted = false;
        }
        return swapCompleted;
    }

    function _calculateMaxLiquidity(uint ethBalance, uint tokenBalance) internal view returns (uint tokenLiquidity, uint ethLiquidity) {
        (uint112 reserve0, uint112 reserve1,) = liquidityPool.getReserves();
        uint ethReserve;
        uint tokenReserve;
        if (address(token) == swapRouter.WETH()) {
            ethReserve = reserve1;
            tokenReserve = reserve0;
        } else {
            ethReserve = reserve0;
            tokenReserve = reserve1;
        }

        uint maxEth = (ethReserve * tokenBalance) / tokenReserve;
        uint maxToken = (tokenReserve * ethBalance) / ethReserve;

        ethLiquidity = _min(maxEth, ethBalance);
        tokenLiquidity = _min(maxToken, tokenBalance);

        return (tokenLiquidity, ethLiquidity);
    }

    function _addLiquidity(uint tokenBalance) internal {
        uint ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (uint tokenLiquidity, uint ethLiquidity) = _calculateMaxLiquidity(ethBalance, tokenBalance);
            (uint t, uint e, uint lpt) = swapRouter.addLiquidityETH{value : ethLiquidity}(
                address(token),
                tokenLiquidity,
                (tokenLiquidity * (1000 - liquiditySlippage) / 1000),
                (ethLiquidity * (1000 - liquiditySlippage) / 1000),
                address(this),
                block.timestamp
            );
            emit AddLiquidity(t, e, lpt);
        }
    }

    function _processLiquidity() internal {
        uint tokenBalance = token.balanceOf(address(this));
        if (tokenBalance <= liquidityInsertThreshold) {
            // Do not attempt if token balance lower than threshold
            return;
        }
        // Sell half of tokens
        _swapTokensForETH(tokenBalance / 2);

        // Add remaining tokens as a liquidity
        _addLiquidity(token.balanceOf(address(this)));
    }

    function _setAirdropReceiver(address receiver) internal {
        require(receiver != address(0), "Receiver cant be zero address");
        airdropReceiver = receiver;
        emit AirdropReceiverUpdated(receiver);
    }

    function _setSystemReceiver(address receiver) internal {
        require(receiver != address(0), "Receiver cant be zero address");
        feeReceiver = receiver;
        emit FeeReceiverUpdated(receiver);
    }

    function setDistributionRatios(uint16 systemRatio_, uint16 airdropRatio_, uint16 liquidityRatio_) public onlyOwnerOrManager {
        require(systemRatio_ != 0 && airdropRatio_ != 0 && liquidityRatio_ != 0, "Ratios should higher than zero");
        uint16 total = (systemRatio_ + airdropRatio_ + liquidityRatio_);
        require(total == 1000, "Total ratio should be thousand");
        systemTransferRatio = systemRatio_;
        airdropRatio = airdropRatio_;
        liquidityRatio = liquidityRatio_;
    }

    function distribute(uint amount) external onlyOwnerOrManager {
        uint balance = token.balanceOf(address(this));
        if (balance < amount) {
            emit DistributionFailed(amount, balance);
        } else {
            (uint sysAmount,) = _thousandRatio(amount, systemTransferRatio);
            (uint airdropAmount,) = _thousandRatio(amount, airdropRatio);
            uint lpAmount = (amount - sysAmount - airdropAmount);

            // Transfer system fee
            token.safeTransfer(feeReceiver, sysAmount);
            totalSystemCommissionAmount += sysAmount;

            // Transfer airdrop
            token.safeTransfer(airdropReceiver, airdropAmount);
            totalAirdropAmount += airdropAmount;

            // Process liquidity
            totalLiquidityAmount += lpAmount;
            _processLiquidity();
        }
    }
}
