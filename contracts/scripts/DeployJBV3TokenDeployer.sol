// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '../JBV3TokenDeployer.sol';
import 'forge-std/Script.sol';


contract Deploy_JB_V3_Token_Deployer_On_Mainnet is Script {
    
    IProjects v1ProjectDirectory = IProjects(0x9b5a4053FfBB11cA9cd858AAEE43cc95ab435418);
    IJBProjects v3_v2_ProjectDirectory = IJBProjects(0xD8B4359143eda5B2d763E127Ed27c77addBc47d3);
    IJBV3TokenStore tokenStore = IJBV3TokenStore(0x6FA996581D7edaABE62C15eaE19fEeD4F1DdDfE7);
    JBV3TokenDeployer v3TokenDeployer;

    function run() external {
      vm.startBroadcast();

      v3TokenDeployer = new JBV3TokenDeployer(v3_v2_ProjectDirectory, v1ProjectDirectory, tokenStore);
      console.log(address(v3TokenDeployer));
    }
}

  /**
  * @notice for testnet purpose ONLY
  */
contract MockV1ProjectDirectory {
    function ownerOf(uint256 _projectId) external view returns (address) {
      _projectId;
      return msg.sender;
    }
}

contract Deploy_JB_V3_Token_Deployer_On_Goerli is Script {
    
    IProjects v1ProjectDirectory = IProjects(address(new MockV1ProjectDirectory()));

    IJBProjects v3_v2_ProjectDirectory = IJBProjects(0x21263a042aFE4bAE34F08Bb318056C181bD96D3b);
    IJBV3TokenStore tokenStore = IJBV3TokenStore(0x1246a50e3aDaF684Ac566f0c40816fF738F309B3);
    JBV3TokenDeployer v3TokenDeployer;

    function run() external {
      vm.startBroadcast();

      v3TokenDeployer = new JBV3TokenDeployer(v3_v2_ProjectDirectory, v1ProjectDirectory, tokenStore);
      console.log(address(v3TokenDeployer));
    }
}