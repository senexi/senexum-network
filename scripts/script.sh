#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Senexum BC network end-to-end test"
echo
CHANNEL_NAME="$1"
DELAY="$2"
: ${CHANNEL_NAME:="world-domination-channel"}
: ${TIMEOUT:="80"}
: ${DELAY:="10"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/orderer.senexum.com/orderers/cyberdyne.orderer.senexum.com/msp/tlscacerts/tlsca.orderer.senexum.com-cert.pem

echo "Channel name : "$CHANNEL_NAME

# verify the result of the end-to-end test
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
		echo
   		exit 1
	fi
}

setGlobals () {

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="CyberdyneMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/cyberdyne.senexum.com/peers/peer0.cyberdyne.senexum.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/cyberdyne.senexum.com/users/Admin@cyberdyne.senexum.com/msp
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.cyberdyne.senexum.com:7051
		else
			CORE_PEER_ADDRESS=peer1.cyberdyne.senexum.com:7051
			CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/cyberdyne.senexum.com/users/Admin@cyberdyne.senexum.com/msp
		fi
	else
		CORE_PEER_LOCALMSPID="UmbrellaMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/umbrella.senexum.com/peers/peer0.umbrella.senexum.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/umbrella.senexum.com/users/Admin@umbrella.senexum.com/msp
		if [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer0.umbrella.senexum.com:7051
		else
			CORE_PEER_ADDRESS=peer1.umbrella.senexum.com:7051
		fi
	fi

	env |grep CORE
}

createChannel() {
	setGlobals 0

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o cyberdyne.orderer.senexum.com:7050 -c $CHANNEL_NAME -t 10 -f ./channel-artifacts/channel.tx >&log.txt
	else
		peer channel create -o cyberdyne.orderer.senexum.com:7050 -c $CHANNEL_NAME -t 10 -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
  PEER=$1
  setGlobals $PEER

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o cyberdyne.orderer.senexum.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o cyberdyne.orderer.senexum.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep $DELAY
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep $DELAY
		joinWithRetry $1
	else
		COUNTER=1
	fi
  verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in 0 1 2 3; do
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep $DELAY
		echo
	done
}

installChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02 >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o cyberdyne.orderer.senexum.com:7050 -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('CyberdyneMSP.member','UmbrellaMSP.member')" >&log.txt
	else
		peer chaincode instantiate -o cyberdyne.orderer.senexum.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('CyberdyneMSP.member','UmbrellaMSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep $DELAY
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$2" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	exit 1
  fi
}

chaincodeInvoke () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o cyberdyne.orderer.senexum.com:7050 -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	else
		peer chaincode invoke -o cyberdyne.orderer.senexum.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for cyberdyne..."
updateAnchorPeers 0
echo "Updating anchor peers for umbrella..."
updateAnchorPeers 2

## Install chaincode on Peer0/cyberdyne and Peer2/umbrella
echo "Installing chaincode on cyberdyne/peer0..."
installChaincode 0
echo "Install chaincode on umbrella/peer2..."
installChaincode 2

#Instantiate chaincode on Peer2/umbrella
echo "Instantiating chaincode on umbrella/peer2..."
instantiateChaincode 2

#Query on chaincode on Peer0/cyberdyne
echo "Querying chaincode on cyberdyne/peer0..."
chaincodeQuery 0 100

#Invoke on chaincode on Peer0/cyberdyne
echo "Sending invoke transaction on cyberdyne/peer0..."
chaincodeInvoke 0

## Install chaincode on Peer3/umbrella
echo "Installing chaincode on umbrella/peer3..."
installChaincode 3

#Query on chaincode on Peer3/umbrella, check if the result is 90
echo "Querying chaincode on umbrella/peer3..."
chaincodeQuery 3 90

echo
echo "========= All GOOD, Senexum BC network end-to-end execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
