#ifndef PARSE_SIRF_H
#define PARSE_SIRF_H


void parseSirf(tmsg_t *msg);

void parseNavData(tmsg_t *msg);

void parseTrackerData(tmsg_t *msg);

void parseRawTracker(tmsg_t *msg);

void parseSoftVers(tmsg_t *msg);

void parseClockStat(tmsg_t *msg);

void parseErrorID(tmsg_t *msg);

void parseCommAck(tmsg_t *msg);

void parseCommNack(tmsg_t *msg);

void parseVisList(tmsg_t *msg);

void parseAlmData(tmsg_t *msg);

void parseOkToSend(tmsg_t *msg);

void parseNavLibDataMeas(tmsg_t *msg);

void parseGeodeticData(tmsg_t *msg);

void parsePps(tmsg_t *msg);

void parseDevData(tmsg_t *msg);

void knownMsg(int id);

void parseUnkMsg(tmsg_t *msg);

void hexprint(uint8_t *ptr, int len);

#endif
