// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@jbx-protocol-v1/contracts/interfaces/IProjects.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBProjects.sol';
// since importing v3 & v2 contract together give compilation issues because of same contract names & setFor isn't available in the v2 interface so using this custom interface
import './interfaces/IJBV3TokenStore.sol';
import './JBV3Token.sol';
 


/** 
  @notice
  V3 token deployer which is used by owners of v1 & v2 projects to deploy v3 token for their v3 project.
*/
contract JBV3TokenDeployer {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//
  error NOT_OWNER();

  //*********************************************************************//
  // --------------------------- events ------------------------- //
  //*********************************************************************//
  event Deployed(uint256 v3ProjectId, address v3Token, address owner);

  /** 
    @notice
    The V1 project directory instance. 
  */
  IProjects public immutable v1ProjectDirectory;

  /** 
    @notice
    The V3 & V2 project directory instance (since both use 1 directory instance)
  */
  IJBProjects public immutable v3_v2_ProjectDirectory;


  /** 
    @notice
    The V3 token store.
  */
  IJBV3TokenStore public immutable tokenStore;


    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//
    /** 
      @param _v3_v2_ProjectDirectory V3 & V2 project directory address.
      @param _v1ProjectDirectory V1 project directory address.
    */
    constructor(IJBProjects _v3_v2_ProjectDirectory, IProjects _v1ProjectDirectory, IJBV3TokenStore _tokenStore) {
      v3_v2_ProjectDirectory = _v3_v2_ProjectDirectory;
      v1ProjectDirectory = _v1ProjectDirectory;
      tokenStore = _tokenStore;
    }


    /**
      @param _name The name of the token.
      @param _symbol The symbol that the token should be represented by.
      @param _projectId The ID of the project that this token should be exclusively used for. Send 0 to support any project.
      @param _v1TicketBooth V1 Token Booth Instance.
      @param _v2TokenStore V2 Token Store Instance.
      @param _v2ProjectId V2 Project Id.
      @param _v1ProjectId V1 Project Id.
    */
    function deploy(
      string memory _name,
      string memory _symbol,
      uint256 _projectId,
      ITicketBooth _v1TicketBooth,
      IJBTokenStore _v2TokenStore,
      uint128 _v2ProjectId,
      uint128 _v1ProjectId
      ) external { 
          // only the project owner an deploy the token
          if (_v1ProjectId != 0 && v1ProjectDirectory.ownerOf(_v1ProjectId) != msg.sender)
            revert NOT_OWNER();
        
          if (_v2ProjectId != 0 && v3_v2_ProjectDirectory.ownerOf(_v2ProjectId) != msg.sender)
            revert NOT_OWNER();
        
          if (_projectId != 0 && v3_v2_ProjectDirectory.ownerOf(_projectId) != msg.sender)
            revert NOT_OWNER();

          JBV3Token _v3Token = new JBV3Token(_name, _symbol, _projectId, _v1TicketBooth, _v2TokenStore, _v2ProjectId, _v1ProjectId);
          // attachhing the token to the project
          tokenStore.setFor(_projectId, _v3Token);

          // transferring the ownership to the project owner
          _v3Token.transferOwnership(_projectId, msg.sender);

          emit Deployed(_projectId, address(_v3Token), msg.sender);
    }
}