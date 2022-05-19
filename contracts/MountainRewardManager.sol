
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./Ownable.sol";




contract MountainRewardManager is Ownable {

    // Total number of nodes
    uint256 public numberOfNodes = 0;


    // The minimum claim time between two claims
    uint128 public claimMinTime = 12*60*60; //12 hours in seconds
    uint128 constant ONE_DAY = 24*60*60; // 24 hours in seconds

    // The main structure that holds information of Nodes.
    struct MountainNode {
        uint256 id;        // The unique identifier of the node
        uint256 timestamp; // The creation time or the last claim time
        uint256 nodeType;  // 0: Ice, 1: Earth, 2: Lava, 3: Exclusive
        address owner;     // The address of the node owner 
    }

    // The prices of the Ice, the Earth, the Lava and the exclusive nodes
    uint256[4] public nodePrice = [10 * 10**18, 15* 10**18, 20* 10**18, 50*10*18];

    // The daily rewards of the Lava, the earth and the Snow nodes (0.8%, 1%, 1.2% and 2%) 
    uint256[4] public dailyReward = [8, 10, 12, 15];

    // Daily boost for the first two days with an exclusive node (2%)
    uint256 public dailyBoost = 20;

    // Instead of percentages we use per mille, so that we can have one decimal percentages
    uint256 constant PER_MILLE = 1000;

    // Mapping that stores the node identifiers for given addresses 
    mapping(address => uint256[]) public accountNodes;
   

    // Mapping that stores the referral id for given addresses 
    mapping(address => bytes20) private referrals;

    // Mapping that allows to retrive the address of a user from the referral id
    mapping(bytes20 => address) internal getAddressFromReferral;    // Note : make it public for tests

    // Mapping that stores the Node structure for given node identifiers
    mapping(uint256 => MountainNode) public nodeMapping;

    // Is the creation of nodes enabled 
    bool public nodeCreationEnabled = true; // Note : True for tests

    // Enables reward claims
    bool public nodeRewardEnabled = true;   // Note : True for tests 


    constructor() {}
   



    /** 
        @param _amount : The amount corresponding to the price of a the node  
        @param _nodeType : The node type (Ice, Earth or Lava). Should be a uint between 0 and 2s
        
        @dev This is the main function to create a node
    */ 
    function createNode(uint256 _amount, uint256 _nodeType) internal { 

        address sender = _msgSender();


        // Revert if the node creation hasn't been enabled yet
        require(nodeCreationEnabled, "Node creation is disabled");
        // Revert if the node type isn't in the list (between 0 and 3)
        require(_nodeType >= 0 && _nodeType <= 3, "Node type is invalid");
        // Revert if the amount sent doesn't match the price of the node
        require(_amount == nodePrice[_nodeType], "Node amount not correct");
        

        // The nodeID is the identifier of the node, it is incremented at each node creation. It
        // is therefore unique to each node
        uint256 nodeID = numberOfNodes + 1;

        // Declare a MountainNode structure that holds the id, the creation time, the type and the address of the owner
        MountainNode memory nodeToCreate;

        // Create the node by assigining the variables to the field of the struct
        nodeToCreate = MountainNode({
            id: nodeID,
            timestamp: block.timestamp,
            nodeType: _nodeType,
            owner: sender
        });

        // The number of nodes' counter is incremented to keep track
        numberOfNodes++;

        // Store the node created in an array that maps nodeIds to nodes
        nodeMapping[nodeID] = nodeToCreate;

        // Store the nodeID in an array that maps addresses to IDs
        accountNodes[sender].push(nodeID);

        // Create a referral code if this is the first time the user create a node
        if (referrals[sender] == 0) {
            bytes20 referral_code = createReferralCode(sender);
            referrals[sender] = referral_code;
            getAddressFromReferral[referral_code] = sender;

        }

    }


    /** 
        @dev This function returns the referral code of the sender
    */ 
    function getReferralCode() external view  returns(bytes20) { 
        return referrals[_msgSender()];
    }




    /**    
        @dev This is the main function to get all rewards before transferring to the owner
        @notice This function was made public
    */ 
    function getAllReward() public returns(uint256) {

        // Revert if the node reward claim hasn't been enabled yet
        require(nodeRewardEnabled, "Node reward claim hasn't been enabled yet");        

        address sender = _msgSender();
        
        // Retrieve the number of nodes of the caller
        uint256 numOwnedNodes = accountNodes[sender].length;
        require(numOwnedNodes > 0, "Must own nodes to claim rewards");
        uint256 totalClaim = 0;
        for(uint256 i = 0; i < numOwnedNodes; i++) {
            if(rewardsClaimable(nodeMapping[accountNodes[sender][i]].timestamp)) {
                uint256 nodeID = nodeMapping[accountNodes[sender][i]].id;
                totalClaim += calculateRewards(nodeID);
                nodeMapping[nodeID].timestamp = block.timestamp;
            }
        }
        return totalClaim;
    }


    /** 
        @param _id : The identifier of the node that the owner wants to get rewards from.  
        
        @dev This is the main function to get reward of node given its NodeId, before transferring to the owner
        @notice This function was made public
    */ 
    function getNodeReward(uint256 _id) public returns(uint256){

        // Revert if the node reward claim hasn't been enabled yet
        require(nodeRewardEnabled, "Node reward claim hasn't been enabled yet");          

        // Retrieve the Node structure given its id 
        MountainNode memory mountaintNode = nodeMapping[_id];

        // Revert if the caller isn't the owner of the Node
        require(_msgSender() == mountaintNode.owner, "Must be owner of node to claim");
        // Revert if it's too soon to claim the rewards
        require(rewardsClaimable(mountaintNode.timestamp), "Node rewards are not claimable yet");

        // Calculate the rewards for the given node
        uint256 amount = calculateRewards(mountaintNode.id);

        // Update the timestamp, it's a way to reset the rewards
        nodeMapping[mountaintNode.id].timestamp = block.timestamp;

        // Return the amount of rewards to the main contract so that it can be sent to the owner of the node
        return amount;
    }


    /** 
        @param _id : The identifier of the node.  
        
        @dev This function calculates reward every time it's called. Contrary to classical Node SC, 
             we believe that this way of doing is more efficient gas-wise. The reward is calculated based on the last
             time it was claimed (or the first time the node was created), and on the daily reward.
    */ 
    function calculateRewards(uint256 _id) public view returns (uint256) {

        // Retrieve the Node structure given its id 
        MountainNode memory mountainNode = nodeMapping[_id];

        uint256 dailyInterest = dailyReward[mountainNode.nodeType];
        // Add an extra boost for the first two days for the exclusive node
        if (mountainNode.nodeType == 3 && 
            (block.timestamp - mountainNode.timestamp) < 2*ONE_DAY ) 
        { 
            dailyInterest+=dailyBoost;
        }

        // The formula to calculate the rewards is simple, and similar to staking SCs. 
        // It corresponds to the node price * daily interest * days elapsed
        return (( (nodePrice[mountainNode.nodeType] * dailyInterest) / PER_MILLE)
                                  * (block.timestamp - mountainNode.timestamp) / ONE_DAY);
    }


    /**    
        @param sender : The adddress of the sender
        @return sender_timestamp_hash : The referral code (the hash of the sender address and the timestamp)

        @dev This function uses the address of the sender and the current timestamp to create a referral code
    */ 
    function createReferralCode(address sender) internal view returns (bytes20 sender_timestamp_hash)
    {
        return ripemd160(abi.encodePacked(sender, block.timestamp));
    }

    /** 
        @param nodeTimestamp : The timestamp of the node (either the creation time or the last time the rewards were claimed)  
        @return bool         : True if at least claimMinTime has passed between two claim

        @dev This function ensures that the claimMinTime between two claims is respected
    */ 
    function rewardsClaimable(uint256 nodeTimestamp) internal view returns(bool) {   
        return (block.timestamp - nodeTimestamp) > claimMinTime;
    }

    /** 
        @param enableNodeCreation : Boolean to enable or disable the node creation  
    */ 
    function setNodeCreation(bool enableNodeCreation) external onlyOwner { 
        nodeCreationEnabled = enableNodeCreation;
    }

    /** 
        @dev Utility function to get all ids for a given address  
    */ 
    function getAccountNodes() public view returns (uint256[] memory) {
            return accountNodes[msg.sender];
    }    



    /** 
        @param node_type : The node type (Lava, Earth or Snow). Must be between 0 and 2 
        @return  uint256 : The current node price for the given type  
    */ 
    function getNodePrice(uint256 node_type) external view returns(uint256) { 
        require(node_type >= 0 && node_type <= 2, "Node type is invalid");
        return nodePrice[node_type];
    }

    /** 
        @param Ice  : The amount of tokens (without the decimals) of the Ice node 
        @param Earth  : The amount of tokens (without the decimals) of the Earth node 
        @param Lava : The amount of tokens (without the decimals) of the Lava node 

    */ 
    function setNodePrice(uint256 Ice, uint256 Earth, uint256 Lava) external onlyOwner {
        nodePrice[0] = Ice * 10**18;
        nodePrice[1] = Earth * 10**18;
        nodePrice[2] = Lava * 10**18;
    }

    /** 
        @param Ice  : The daily reward (in percentages) for the Ice node 
        @param Earth  : The daily reward (in percentages) for the Earth node 
        @param Lava : The daily reward (in percentages) for the Lava node 

        @dev The percentages are set with 100% corresponding to 1_000 (Meaning 10% = 100)

    */ 
    function setRewardPerNode(uint256 Ice, uint256 Earth, uint256 Lava) external onlyOwner {
        dailyReward[0] = Ice;
        dailyReward[1] = Earth;
        dailyReward[2] = Lava;
    }

    /** 
        @param newTime  : The new min claim time that needs to be respected before claiming reward 
    */ 
    function setClaimTime(uint128 newTime) external onlyOwner {
        claimMinTime = newTime;
    }

    /** 
        @param account  : The address of the account that supposedly has nodes
        @return uint256 : The number of nodes the account has

    */ 
    function getNumberOfNodes(address account) external view returns (uint256) {
        return accountNodes[account].length;
    }

    /** 
        @param account  : The address of the account that supposedly has nodes
        @return bool    : True if the account has at least one Node

    */ 
    function isNodeOwner(address account) public view returns (bool) {
        return accountNodes[account].length>0;
    }


}




    // The transfer of nodes is not possible for now, waiting for a guildeline from the team to see if
    // we include it or not

    // /** 
    //     @param _id : The identifier of the node that the owner wants to to transfer  
    //     @param _owner : The owner of the node with given id
    //     @param _recipient : The new owner of the node with given id 

    //     @notice TODO : For now it is only doable by the owner of the contract

    //     @dev This function loops over the nodes of the owner and if it finds the node with given id,
    //          it removes it from the owner list and add it to the recipient's list of nodes
    // */ 
    // function transferNode(uint256 _id, address _owner, address _recipient) public onlyOwner {

    //     require(_owner != _recipient, "Cannot transfer to self");

    //     uint256 len = accountNodes[_owner].length;
    //     bool success = false;
    //     for(uint256 i = 0; i < len; i++) {
    //         if(accountNodes[_owner][i] == _id) {
    //             accountNodes[_owner][i] = accountNodes[_owner][len-1];
    //             accountNodes[_owner].pop();
    //             accountNodes[_recipient].push(_id);
    //             nodeMapping[_id].owner = _recipient;
    //             success = true;
    //             break;
    //         }
    //     }
    //     require(success, "Transfer failed");
    // } 