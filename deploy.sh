# #!/bin/bash

# # Configurações para Base Sepolia
# BASE_SEPOLIA_RPC="https://sepolia.base.org"
# BASE_SEPOLIA_CHAIN_ID=84532
# BASE_SEPOLIA_ETHERSCAN="https://api-sepolia.basescan.org/api"

# # Obtenha sua API key do BaseScan (https://basescan.org)

# # Execute o script de deploy com verificação
# forge script script/Deploy.s.sol:DeployScript \
#   --rpc-url $BASE_SEPOLIA_RPC \
#   --broadcast \
#   --verify \
#   --account faucets \
#   -vvvv


# # forge script script/Deploy.s.sol:DeployScript --account ff80 --rpc-url http://127.0.0.1:8545 --broadcast



# Verifique os contratos já deployados
0x0B971C4e62AB0eC19CaF3eBb0527e8A528fcAdD6 USDC
0xB457f5908dE044843C90aA1771D999dA8A9Bf3fD PaymentVault
0xE7c3e1C1F678cDfE8651556F28c396A38CC88E8D CampaignManager
0x101De02821A2b148c49cd39d2182dB216C74DC5F OracleConnector