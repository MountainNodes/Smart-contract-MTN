
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./ARC20.sol";
import "./IARC20.sol";
import "./PaymentSplitter.sol";
import "./Context.sol";
import "./ITraderJoeFactory.sol";
import "./ITraderJoeRouter.sol";
import "./MountainRewardManager.sol";




contract Mountain is ARC20, MountainRewardManager {

    // In the constructor competitors usually provide :
    // _ Addresses for the reward, treasury and liquidity handler pools
    // _ Initial balances of tokens for those pools
    

    // A setLiquidityPool function (with an array) like in PolarNodes ?

    // Later : Need to take into account the presale tokens



    //-----------------------------------------------------\\
    //----------- Token variables -------------------------\\
    //-----------------------------------------------------\\  
    string constant _name = 'Mountain';
    string constant _symbol = 'MTN';
    uint8 constant _decimals = 18;
    uint256 _totalSupply = 1_000_000 * (10 ** _decimals);   // 1 Million tokens (as defined in the WP)



    //-----------------------------------------------------\\
    //--------------- Pools -------------------------------\\
    //-----------------------------------------------------\\
    address public treasuryPool;
    address public rewardPool; 
    address public teamPool; 
    address public liquidityPool; // Todo: do we need an address for the LP tokens ? 

	mapping(address => bool) private _isPool;


    // Initial allocation of tokens (TODO : replace this)
    uint64 ownerAllocation = 20;  // For test purposes (imagine this address being the LP provider)
    uint64 treasuryPoolAllocation = 5;  
    uint64 teamPoolAllocation = 5;  
    uint64 rewardPoolAllocation = 70;
    uint64 allocationDenominator = 100;


    //-----------------------------------------------------\\
    //----------- Fee variables ---------------------------\\
    //-----------------------------------------------------\\

    // Node creation fees
    uint32 public liquidityFee = 100; // 10%
    uint32 public rewardFee = 750; // 75%
    uint32 public treasuryFee = 100; // 10% 
    uint32 public teamFee = 50; // 5% 
    uint32 public totalCreationFees = liquidityFee + rewardFee + treasuryFee + teamFee;

    uint32 public rewardSwapRatio = 25; // 2.5% TODO : check if necessary

    // Claim and sell fees
    uint32 public claimFee = 50; // 5%
    uint32 public sellFee = 100;// 10%

    // Transfer fee (Not implemented yet)
    uint32 public transferFee = 500;// 50%

    // Sell fees for the first two days
    uint256 constant TWO_DAYS = 2*24*60*60; // two days in second
    uint256 public launchSellFeeTimestamp;
    uint256 public  endSellFeeTimestamp;
    uint256 public initialAdditionnalSellFee = 150; // 15% that will decrease to zero after two days


    // Referral bonus
    uint256 public referral_bonus = 50; //5%


    //-----------------------------------------------------\\
    //----------- Auto Liquidity variables ----------------\\
    //-----------------------------------------------------\\   

    ITraderJoeRouter private traderJoeRouter;
    address public traderJoePair;
    address public traderJoePairTest;

    //address private traderJoeRouterAddress = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4; // TraderJoe MainNet
    //address private traderJoeRouterAddress = 0x5db0735cf88F85E78ed742215090c465979B5006; // TraderJoe testnet TODO : change this
    address private traderJoeRouterAddress = 0x2D99ABD9008Dc933ff5c0CD271B88309593aB921;   // Pangolin testnet
    

    bool public swapping = false;


    //-----------------------------------------------------\\
    //----------- Transfer related variables --------------\\
    //-----------------------------------------------------\\   

    /* Before transferring tokens/Avax to the pools, the min num of tokens accumulated with the fees needs
       to be at least equal to swapTokensAmount. */     
    uint256 public swapTokensAmount = 100 * (10 ** _decimals); // TODO : define with the team    

    // Max tokens per tx and per wallet
    uint256 private maxTx = 500 * (10 ** _decimals);
    uint256 private maxWallet = 4_000 * (10 ** _decimals);

   	bool private tradingOpen = true; // TODO : Need to change this before launching (set to true for testing purposes)

    // List of blacklisted malicious addresses (opportunists that try to buy before trading actually opened)
    mapping(address => bool) public _isBlacklisted;

    // Mapping that for whitelisted to create a free node
    mapping(address => bool) public _isWhitelisted; 

    //-----------------------------------------------------\\
    //----------- Presale variables -----------------------\\
    //-----------------------------------------------------\\   

    IARC20 presaleToken;
    uint256 presaleMax = 1500*10**18;

    //-----------------------------------------------------\\
    //----------- Events and modifiers --------------------\\
    //-----------------------------------------------------\\  


    modifier inSwap {
        swapping = true;
        _;
        swapping = false;
    }


    event SwapAndLiquify(uint256 otherHalf, uint256 newBalance);




   constructor(address[] memory addresses) ARC20(_symbol, _name)  {

     
        rewardPool = addresses[0];
        treasuryPool = addresses[1];
        liquidityPool = addresses[2];
        teamPool = addresses[3];

        setIsPool(rewardPool, true);
        setIsPool(treasuryPool, true);
        setIsPool(liquidityPool, true);
        setIsPool(teamPool, true);


        _mint(msg.sender, _totalSupply * ownerAllocation / allocationDenominator); 
        _mint(rewardPool, _totalSupply * rewardPoolAllocation / allocationDenominator); 
        _mint(treasuryPool, _totalSupply * treasuryPoolAllocation / allocationDenominator); 
        _mint(teamPool, _totalSupply * teamPoolAllocation / allocationDenominator); 

        require(totalSupply()==_totalSupply, "MTN CONSTR : Error supply");
   }    



    /** 
        @dev Create pair function : The pair MTN-AVAX is created for the first time on TraderJoe
    */
    function createPair() external onlyOwner {

        // Instantiate a TraderJoe router with current address traderJoeRouterAddress
        traderJoeRouter = ITraderJoeRouter(traderJoeRouterAddress);

        // Create a TraderJoe pair for MTN token
        traderJoePair = ITraderJoeFactory(traderJoeRouter.factory()).createPair(address(this), traderJoeRouter.WAVAX()); 

        // TODO : find a check that the pair was created and make a required in the functions that uses it
    } 


    /** 
        @param account : The address to be blacklisted or not
        @param value   : boolean to set the address to the blacklist or not
    */
    function blacklistMalicious(address account, bool value) external onlyOwner { 
        _isBlacklisted[account] = value;
    }  

    /** 
        @param account : The address to be whitelisted or not
        @param value   : boolean to set the address to the whitelist or not
    */
    function whitelisteUser(address account, bool value) external onlyOwner { 
        _isWhitelisted[account] = value;
    }        
    

    /** 
        @param newVal : Boolean to set the min amount of tokens requested for a multi-swap
    */    
    function setSwapTokensAmount(uint256 newVal) external onlyOwner { 
        swapTokensAmount = newVal; 
    }


    /** 
        @param walletAddress : The new wallet address for the treasury pool
    */  
    function updateTreasuryWallet(address payable walletAddress) external onlyOwner { 
        treasuryPool = walletAddress; 
    }


    /** 
        @param walletAddress : The new wallet address for the reward pool
    */      
    function updateRewardWallet(address payable walletAddress) external onlyOwner { 
        rewardPool = walletAddress; 
    }


    /** 
        @param walletAddress : The new wallet address for the pool that holds the LP tokens
    */      
    function updateLiquidityWallet(address payable walletAddress) external onlyOwner { 
        liquidityPool = walletAddress; 
    }   


    /** 
        @param walletAddress : The new wallet address for the team pool
    */      
    function updateTeamyWallet(address payable walletAddress) external onlyOwner { 
        teamPool = walletAddress; 
    }        


    /** 
        @param value : The new fee for the reward pool when a new node is created
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */  
    function updateRewardsFee(uint32 value) external onlyOwner {
        rewardFee = value;
        totalCreationFees = rewardFee+liquidityFee+treasuryFee;
    }


    /** 
        @param value : The new fee for the LP pool when a new node is created
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */  
    function updateLiquiditFee(uint32 value) external onlyOwner {
        liquidityFee = value;
        totalCreationFees = rewardFee+liquidityFee+treasuryFee;
    }


    /** 
        @param value : The new fee for the team pool when a new node is created
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */  
    function updateTeamFee(uint32 value) external onlyOwner {
        liquidityFee = value;
        totalCreationFees = rewardFee+liquidityFee+treasuryFee;
    }

    /** 
        @param value : The new fee for the treasury pool when a new node is created
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */  
    function updateTreasuryFee(uint32 value) external onlyOwner {
        treasuryFee = value;
        totalCreationFees = rewardFee+liquidityFee+treasuryFee;
    }

    /** 
        @param value : The new fee to be taken at each user claim 
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */  
    function updateClaimFee(uint32 value) external onlyOwner { 
        claimFee = value; 
    }

    /** 
        @param value : The new fee to be taken at each user sell 
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */      
    function updateSellFee(uint32 value) external onlyOwner { 
        sellFee = value; 
    }  

    /** 
        @param value : The new fee to be taken at each user node transfer 
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */      
    function updateTransferFee(uint32 value) external onlyOwner { 
        sellFee = value; 
    }    


    /** 
        @param value : The new reward swap ratio. 
                       This is the percentage of tokens that will be swapped and sent to the reward Pool. 
        @notice The max value for 100% is 1_000, i.e. 100 is 10%
    */     
    function updateRewardSwapRatio(uint32 value) external onlyOwner { 
        rewardSwapRatio = value; 
    }


    /** 
        @param account : The account that is set, or not, as a pool
        @param value : If true the account is set as a pool
    */   
	function setIsPool(address account, bool value) public onlyOwner {
        _isPool[account] = value;
    }

    /** 
        @param value : The new max amount of tokens per tx
    */   
	function updateMaxTx(uint256 value) external onlyOwner {
        maxTx = value;
    }


    /** 
        @param value : The new max amount of tokens per wallet
    */   
	function updateMaxWallet(uint256 value) external onlyOwner {
        maxWallet = value;
    }    

    /** 
        @dev Start trading (after adding liquidity, and waiting some time in order to blacklist bots)
    */   
	function openTrading() external onlyOwner {
        tradingOpen = true;

        // TODO : Check if this is the right place to put it
        launchSellFeeTimestamp = block.timestamp;
        endSellFeeTimestamp = block.timestamp + TWO_DAYS;        
    }

    /** 
        @param account : The address of the account to check if it's a pool address/the owner or this SC
    */   
    function isMTNAddress(address account) internal view returns (bool) {
            return (account == owner() || account == address(this) || _isPool[account]);
    }


    /** 
        @param amount : The amount of tokens to be minted to the reward pool
    */   
	function addTokensToRewardPool(uint256 amount) external onlyOwner {
		require(amount > 0, "Amount too low");
		_mint(rewardPool, amount);
	}

    // Note : Defined in PaymentSplitter, if we use it, remove this function
    receive() external payable {}


    function transfer(address recipient, uint256 amount) public override returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] -= amount;
        }
        return _transfer(sender, recipient, amount);
    }
  
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns(bool){
        
        uint256 amountToTransfer = amount;

        require(from != address(0), "ARC20: transfer from the zero address");
        require(to != address(0), "ARC20: transfer to the zero address"); 
        require(!_isBlacklisted[from] && !_isBlacklisted[to], "Blacklisted address");

		if (!isMTNAddress(from) && !isMTNAddress(to)) {

            
		 	if (tradingOpen) {
		 		uint256 walletBalance = balanceOf(address(to));
                if (!isMTNAddress(to)) {             
		 		    require(amount + walletBalance <= maxWallet, "Transfer amount too high");
                }
                require(amount <= maxTx, 'Transaction Limit Exceeded');
		 	}

			if (!tradingOpen && from == traderJoePair) {
		 		_isBlacklisted[to] = true;
		 	}


            if(from != traderJoePair) {
               amountToTransfer = takeSellFee(from, amount);
            }
		}

       
        _balances[from] = _balances[from] - amountToTransfer;
        _balances[to] = _balances[to] + amountToTransfer;

        emit Transfer(from, to, amountToTransfer);
        return true;
    }



    function takeSellFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = (amount * sellFee) / PER_MILLE;

        if(block.timestamp < endSellFeeTimestamp) {
            feeAmount += ((amount * initialAdditionnalSellFee * 
                                    (TWO_DAYS - (block.timestamp - launchSellFeeTimestamp))) / (TWO_DAYS))
                                    / PER_MILLE;
        }

        _balances[rewardPool] += feeAmount;
        _balances[sender] -= feeAmount;
        
        emit Transfer(sender, rewardPool, feeAmount);

        return amount - feeAmount;
    }


    /** 
        @param tokens : The amount of tokens. 
        @dev For more details, see the functions swapTokensForAvax and addLiquidity
    */  
    function swapAndLiquify(uint256 tokens) private {

        // Split the amount of tokens in half
        uint256 half = tokens/2;
        uint256 otherHalf = tokens-half; //TODO : removed this o ?

        // Store the initial AVAX balance
        uint256 initialBalance = address(this).balance;

        // Swap 50% of the tokens to AVAX
        swapTokensForAvax(half);

        // Calculate the amount of AVAX swapped
        uint256 newBalance = address(this).balance-initialBalance;

        // Add liquidity by adding 50% of tokens and the AVAX that was swapped
        addLiquidity(otherHalf, newBalance);

        // Emit an event for the logs
        emit SwapAndLiquify(otherHalf, newBalance);
    }


    /** 
        @param tokenAmount : The amount of tokens
        @param avaxAmount  : The amount of Avax
        
        @dev This function is responsible for adding liquidity to the liquidity pool MTN-AVAX
             tokenAmount in dollar value = avaxAmount in dollar value.
    */  
    function addLiquidity(uint256 tokenAmount, uint256 avaxAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(traderJoeRouter), tokenAmount);

        // add the liquidity
        traderJoeRouter.addLiquidityAVAX{value: avaxAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityPool,
            block.timestamp
        );
    }


    /** 
        @param tokenAmount : The amount of tokens
        
        @dev This function is responsible for swapping MTN to AVAX
             tokenAmount in dollar value = avaxAmount in dollar value.
    */  
    function swapTokensForAvax(uint256 tokenAmount) private {

        // Compute the path (tokens to AVAX)
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = traderJoeRouter.WAVAX();

        // For a swap of tokens to AVAX, we need to approve spending first
        _approve(address(this), address(traderJoeRouter), tokenAmount);

        // Call the TraderJoe swapping function
        // Todo : check why we need supportingFee
        traderJoeRouter.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of AVAX
            path,
            address(this),
            block.timestamp
        );
    }    

    /** 
        @param destination : The address of the pool where the AVAX are sent
        @param tokens      : The amount of tokens to be swapped to AVAX
    */ 
    function swapAndSendToPool(address destination, uint256 tokens) private {
        
        // Store the initial AVAX balance of the SC
        uint256 initialAVAXBalance = address(this).balance;

        // Swap tokens to AVAX
        swapTokensForAvax(tokens);

        // Get the total amount of AVAX that was swapped
        uint256 newBalance = (address(this).balance)-initialAVAXBalance;

        // Send it to the pool
        payable(destination).transfer(newBalance);
    }



    /** 
        @param contractTokenBalance : The amount of tokens in this contract
        
        @dev This function handles all the transfers at a node creation 
             when there is enough tokens in the contract
    */  
    function multi_swapping(uint256 contractTokenBalance) private inSwap{
            
        // Swap some tokens for Avax and send them to the treasury pool
        uint256 treasuryTokens = contractTokenBalance * treasuryFee / PER_MILLE;
        swapAndSendToPool(treasuryPool, treasuryTokens);

        // Send some tokens and Avax to the reward pool
        uint256 rewardsPoolTokens = contractTokenBalance * rewardFee / PER_MILLE;
        uint256 rewardsTokenstoSwap = rewardsPoolTokens * rewardSwapRatio / PER_MILLE;

        swapAndSendToPool(rewardPool, rewardsTokenstoSwap);
        _transfer(address(this),rewardPool, rewardsPoolTokens-rewardsTokenstoSwap);

        // Swap half of some tokens and add liquidity
        uint256 swapTokens = contractTokenBalance * liquidityFee / PER_MILLE;
        swapAndLiquify(swapTokens);

        // Swap the rest to Avax and send it to the team Pool
        swapAndSendToPool(teamPool, balanceOf(address(this)));

        // // Swap the rest to Avax and keep it in this SC (Old classical way, using payment splitter)
        // swapTokensForAvax(balanceOf(address(this)));        

    }

    /** 
        @param amount : The amount of tokens needed for the node creation 
        @param nodeType : The node type (Lava, Earth or Snow). Should be a uint between 0 and 2.
        @param referral_code : The referral code (bytes20(0) if None)
        
        @dev This function handles the node creation, by calling the nodeRewardManager, 
             and all the transfers to the different pools when there is enough tokens in the contract
    */  
    function createNodeAndTransferToPools(uint256 amount, uint256 nodeType, bytes20 referral_code) public returns (bytes20) {


        address sender = _msgSender();
        require(sender != address(0),
                "NODE CREATION: from the 0 address");
        require(!_isBlacklisted[sender], 
                "NODE CREATION: Blacklisted address");
        require(sender != treasuryPool && sender != rewardPool,
                "NODE CREATION: Pools cannot create nodes");


        uint256 contractTokenBalance = balanceOf(address(this));
        bool swapAmountOk = contractTokenBalance >= swapTokensAmount;
        if (!swapping && swapAmountOk) {
            multi_swapping(contractTokenBalance);
        }


        bytes20 referral_code_sender = super.createNode(amount, nodeType);

       // If the sender is whitelisted he can create a free node
        if (_isWhitelisted[sender]) {
            _isWhitelisted[sender] = false;
        }
        else {

            uint256 amount_to_reward_pool = amount;

            // Get the address of the referral (if no referral code => 0 address) 
            address referral = getAddressFromReferral[referral_code];

            if (referral != address(0)) {

                uint256 amount_to_referral = referral_bonus * amount_to_reward_pool / PER_MILLE;
                amount_to_reward_pool -= amount_to_referral;

                // Send 5% of the amount to the referral
                _transfer(_msgSender(), referral, amount_to_referral);
            }

            // TODO: add a require balance ?x
            _transfer(_msgSender(), address(this), amount_to_reward_pool);  
        }   

        return referral_code_sender;

    }    

    /** 
        @param id : The identifier of the node 
        
        @dev This function uses the identifier to get the rewards of the node and send it to the 
             owner.
    */ 
    function claimRewards(uint256 id) public {

        address sender = _msgSender();

        // Revert if the sender is the 0 address, blacklisted or a pool address
        require(sender != address(0),    
                "CLAIM REWARD: from the 0 address");
        require(!_isBlacklisted[sender], 
                "CLAIM REWARD: Blacklisted address");
        require(sender != treasuryPool && sender != rewardPool,
                "CLAIM REWARD: Pools cannot claim rewards");

        // Uses the nodeRewardManager to get the amount for reward for the node of given id
        uint256 node_reward = super.getNodeReward(id);

        // A percentage of fee, the claimFee, is applied and some tokens are be kept in the in the reward pool
        uint256 feeAmount = node_reward*claimFee/PER_MILLE;
        node_reward -= feeAmount;
                     

        // Transfer the reward to the owner of the node with given id
        _transfer(rewardPool, sender, node_reward);
    }


    function claimAllRewards() public {

        address sender = _msgSender();

        // Revert if the sender is the 0 address, blacklisted or a pool address
        require(sender != address(0),
                "CLAIM REWARD: from the 0 address");
        require(!_isBlacklisted[sender], 
                "CLAIM REWARD: Blacklisted address");
        require(sender != treasuryPool && sender != rewardPool,
                "CLAIM REWARD: Pools cannot claim rewards");

        // Uses the nodeRewardManager to get the amount for all rewards for the nodes of the sender
        uint256 node_reward = super.getAllReward();

        // A percentage of fee, the claimFee, is applied and some tokens are be kept in the reward pool
        uint256 feeAmount = node_reward*claimFee/PER_MILLE;
        node_reward -= feeAmount;
        
        // Transfer all the rewards to the owner of the nodes       
        _transfer(rewardPool, sender, node_reward);
    }    

    /* -------------------- PRESALE -------------------- */



    function setPresaleToken(address _presaleToken) external onlyOwner {
        presaleToken = IARC20(_presaleToken);
    }

    function convertPresaleToReal() external {
        require(address(presaleToken) != address(0), "Presale token not set");
        uint256 balance = presaleToken.balanceOf(msg.sender);
        require(balance > 0 && balance <= presaleMax, "Invalid balance");

        presaleToken.transferFrom(msg.sender, address(this), balance);
        require(presaleToken.balanceOf(msg.sender) == 0, "Error with conversion");
        
        _mint(msg.sender, balance);
    }

}