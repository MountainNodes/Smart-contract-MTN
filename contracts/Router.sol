// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

contract Router {
    
    function WAVAX() external pure returns (address) {}

	function addLiquidityAVAX(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountAVAXMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountAVAX, uint liquidity) {}
    
    
     function swapExactAVAXForTokens(
     	uint amountOutMin, 
     	address[] calldata path, 
     	address to, 
     	uint deadline
     	) external payable returns (uint[] memory amounts) {}
    
    function swapAVAXForExactTokens(
     	uint amountOut,
     	address[] calldata path,
     	address to, 
     	uint deadline
     ) external payable returns (uint[] memory amounts) {}
     
     
     
    function getAmountsOut(
     	uint256 amountIn, 
     	address[] calldata path
     ) external view  returns (uint256[] memory amounts) {}

    function getAmountsIn(
     	uint256 amountOut, 
     	address[] calldata path
     ) external view  returns (uint256[] memory amounts) {}

    function swapTokensForExactAVAX(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual returns (uint256[] memory amounts) {}
     
   function swapExactTokensForAVAXSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external view {}     
    
     
   function swapExactTokensForAVAX(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external view returns (uint[] memory amounts) {}
     
  
        
     
}



