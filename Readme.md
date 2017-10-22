# Hyperledger fabric example

First try out of a Hyperledger Fabric network based on the 'build your first network' tutorial. This sample includes the use of CAs, Apache Kafka / Zookeeper, and multiple orderer peers. 

For reference check the official tutorial: ["Build Your First Network"](http://hyperledger-fabric.readthedocs.io/en/latest/build_network.html)

## Prequisites

Make sure you got the platform-specific binaries installed just as descibed ["here"](https://hyperledger-fabric.readthedocs.io/en/latest/samples.html)

## Layout

The network should be used by two (famous) organizations - Cyberdyne Cooperation and Umbrella Cooperation.

- Zookeeper 1
- Zookeeper 2
- Zookeeper 3
- Kafka 1
- Kafka 2
- Kafka 3
- Kafka 4
- CA Cyberdyne
- CA Umbrella
- Orderer
    - cyberdyne.orderer.senexum.com
    - umbrella.orderer.senexum.com
- Peers
    - Cyberdyne
        - peer0.cyberdyne.senexum.com
        - peer1.cyberdyne.senexum.com
    - Umbrella
        - peer0.umbrella.senexum.com
        - peer1.umbrella.senexum.com

## Generate the certificates
All crypto materials are generated using the `cryptogen` tool from the platform-specific binaries.

Create a configuration file `crypto-config.yml` containing the orderer and peer nodes with their specific domain names and run the tool.

`../bin/cryptogen generate --config=./crypto-config.yaml`

It generates a folder `crypto-config` containing all the cryptographic materials.

## Generate the transaction artifacts

Next setup the configuration file `configtx.yaml` for creating the transaction artifacts.

- genesis block
- channel artifact
- anchor peers

The parameter `MSPDir` links the defined organisation to the certificates that have been generated in the previous step.

In the orderer section set the `OrdererType` to kafka and add at least two kafka brokers with their hostname and port (Kafka brokers will be defined in the docker compose file).

The profile section defines the configurtion for generating the different artifacts.

Export the base directory of the project into the variable `FABRIC_CFG_PATH`, since it is required by the `configtxgen` tool.

`export FABRIC_CFG_PATH=$PWD`
`mkdir channel-artifacts`

### genesis block
Create the genesis block using the `TwoOrgsOrdererGenesis` profile.

`../bin/configtxgen -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/genesis.block`

### channel
Create the channel between the parties that have been defined in a profile `TwoOrgsChannel` in `configtx.yaml`. Channel name needs to be set by exporting the `CHANNEL_NAME` variable and must satisfy the following requirements:
1. Contain only lower case ASCII alphanumerics, dots '.' and dashes '-'
2. Are shorter than 250 characters.
3. Start with a letter

`export CHANNEL_NAME=world-domination-channel`
`../bin/configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME`

### anchor peers
After creating the channel, at least one anchorpeer needs to be setup for each organisation. An anchorpeer can always be seen by all other participants of the network. The `-asOrg` parameter should corelated to the organization name used in the `configtx.yaml` (`Organizations` -> `<Organisation>` -> `Name`).

Create anchorpeer for the first organization (Cyberdyne here)
`../bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/CyberdyneMSPanchors.tx -channelID $CHANNEL_NAME -asOrg Cyberdyne`

Create anchorpeer for the second organization (Umbrella here)

`../bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/UmbrellaMSPanchors.tx -channelID $CHANNEL_NAME -asOrg Umbrella`

## Setup docker compose
The file `docker-compose-senexum.yaml` contains the definitions for all containerized components for the blockchain network. Enviroment settings and mounted volumes need changed to be changed to match the files (certificates and keys) and configurations created in the previous steps. 


### Bring up the network
Before bringing up the network, make sure that in the `peer_base.yaml` the parameter `CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=<network>` matches the network name defined in `docker-compose-senexum.yaml` in the `networks` section. Note that docker compose prefixes the network name. To check for network names use `docker network ls` while the composition is running.

Example here: `CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=senexumnetwork_senexum`

Start the network using `docker-compose` command.

`CHANNEL_NAME=$CHANNEL_NAME TIMEOUT=1000 docker-compose -f docker-compose-senexum.yaml up -d`

Bring down the network using `docker-compose -f docker-compose-senexum.yaml down`.

Use `docker rm $(docker ps -a -q)` to remove all containers including the ones running the chaincode.

## Running the script

For testing purposes, the docker compose file also contains an addition container `cli` with includes several tools to interact with the network from the console.

It also includes an end-2-end test script from the `byfn` tutorial.

Within the test Script we need to change domain names, path to certificates, and MSP IDs (also the one in the endorsment policy!)

Enter the CLI container uding `docker exec -it cli bash` and execute the end-2-end test with `./scripts/script.sh`.

See the logs of the CLI container by using `docker logs -f cli`.

### Manual execution

**Invoke**
`peer chaincode invoke -o cyberdyne.orderer.senexum.com:7050  --tls true --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/orderer.senexum.com/orderers/cyberdyne.orderer.senexum.com/msp/tlscacerts/tlsca.orderer.senexum.com-cert.pem -C world-domination-channel -n mycc -c '{"Args":["invoke","a","b","100"]}'`

**Query**
`peer chaincode query -C world-domination-channel -n mycc -c '{"Args":["query","b"]}'`