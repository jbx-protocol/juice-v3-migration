// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IFundingCycles } from '@jbx-protocol-v1/contracts/interfaces/IFundingCycles.sol';
import { ITicketBooth, ITickets } from '@jbx-protocol-v1/contracts/interfaces/ITicketBooth.sol';
import { IProjects } from '@jbx-protocol-v1/contracts/interfaces/IProjects.sol';
import { IJBController } from '@jbx-protocol-v2/contracts/interfaces/IJBController.sol';
import { IJBProjects } from '@jbx-protocol-v2/contracts/interfaces/IJBProjects.sol';
import { IJBTokenStore as IJBV2TokenStore } from '@jbx-protocol-v2/contracts/interfaces/IJBTokenStore.sol';
import { IJBTokenStore as IJBV3TokenStore } from '@jbx-protocol-v3/contracts/interfaces/IJBTokenStore.sol';
import { JBV3Token } from './JBV3Token.sol';

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
  IJBProjects public immutable projectDirectory;

  /** 
    @notice
    The V3 token store.
  */
  IJBV3TokenStore public immutable tokenStore;

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//
  /** 
      @param _projectDirectory V3 & V2 project directory address.
      @param _v1ProjectDirectory V1 project directory address.
    */
  constructor(
    IJBProjects _projectDirectory,
    IProjects _v1ProjectDirectory,
    IJBV3TokenStore _tokenStore
  ) {
    projectDirectory = _projectDirectory;
    v1ProjectDirectory = _v1ProjectDirectory;
    tokenStore = _tokenStore;
  }

  /**
      @param _name The name of the token.
      @param _symbol The symbol that the token should be represented by.
      @param _projectId The ID of the project that this token should be exclusively used for. Send 0 to support any project.
      @param _v1TicketBooth V1 Token Booth Instance.
      @param _v2TokenStore V2 Token Store Instance.
      @param _v1ProjectId V1 Project Id.
    */
  function deploy(
    string memory _name,
    string memory _symbol,
    uint256 _projectId,
    ITicketBooth _v1TicketBooth,
    IJBV2TokenStore _v2TokenStore,
    IFundingCycles _v1FundingCycleStore,
    IJBController _v2Controller,
    IJBController _v3Controller,
    uint128 _v1ProjectId
  ) external {
    // only the project owner an deploy the token
    if (_v1ProjectId != 0 && v1ProjectDirectory.ownerOf(_v1ProjectId) != msg.sender)
      revert NOT_OWNER();

    if (_projectId != 0 && projectDirectory.ownerOf(_projectId) != msg.sender)
      revert NOT_OWNER();

    JBV3Token _v3Token = new JBV3Token(
      _name,
      _symbol,
      _projectId,
      _v1TicketBooth,
      _v2TokenStore,
      _v1FundingCycleStore,
      _v2Controller,
      _v3Controller,
      _v1ProjectId
    );
    // attachhing the token to the project
    tokenStore.setFor(_projectId, _v3Token);

    // transferring the ownership to the project owner
    _v3Token.transferOwnership(address(tokenStore));

    emit Deployed(_projectId, address(_v3Token), msg.sender);
  }
}
