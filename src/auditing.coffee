logger = require 'winston'
syslogParser = require('glossy').Parse
parseString = require('xml2js').parseString
firstCharLowerCase = require('xml2js').processors.firstCharLowerCase
Audit = require('./model/audits').Audit

parseAuditRecordFromXML = (xml, callback) ->
  # DICOM mappers
  csdCodeToCode = (name) -> if name is 'csd-code' then 'code' else name
  originalTextToDisplayName = (name) -> if name is 'originalText' then 'displayName' else name

  options =
    mergeAttrs: true,
    explicitArray: false
    tagNameProcessors: [firstCharLowerCase]
    attrNameProcessors: [firstCharLowerCase, csdCodeToCode, originalTextToDisplayName]

  parseString xml, options, (err, result) ->
    return callback err if err

    if not result?.auditMessage
      return callback new Error 'Document is not a valid AuditMessage'

    audit = {}

    if result.auditMessage.eventIdentification
      audit.eventIdentification = result.auditMessage.eventIdentification

    audit.activeParticipant = []
    if result.auditMessage.activeParticipant
      # xml2js will only use an array if multiple items exist (explicitArray: false), else it's an object
      if result.auditMessage.activeParticipant instanceof Array
        for ap in result.auditMessage.activeParticipant
          audit.activeParticipant.push ap
      else
        audit.activeParticipant.push result.auditMessage.activeParticipant

    if result.auditMessage.auditSourceIdentification
      audit.auditSourceIdentification = result.auditMessage.auditSourceIdentification

    audit.participantObjectIdentification = []
    if result.auditMessage.participantObjectIdentification
      # xml2js will only use an array if multiple items exist (explicitArray: false), else it's an object
      if result.auditMessage.participantObjectIdentification instanceof Array
        for poi in result.auditMessage.participantObjectIdentification
          audit.participantObjectIdentification.push poi
      else
        audit.participantObjectIdentification.push result.auditMessage.participantObjectIdentification

    callback null, audit


exports.processAudit = (msg, callback) ->
  parsedMsg = syslogParser.parse(msg)

  if not parsedMsg or not parsedMsg.message
    logger.info 'Invalid message received'
    return callback()

  parseAuditRecordFromXML parsedMsg.message, (xmlErr, result) ->
    audit = new Audit result

    audit.rawMessage = msg
    audit.syslog = parsedMsg
    delete audit.syslog.originalMessage
    delete audit.syslog.message

    audit.save (saveErr) ->
      if saveErr then logger.error "An error occurred while processing the audit entry: #{saveErr}"
      if xmlErr then logger.info "Failed to parse message as an AuditMessage XML document: #{xmlErr}"

      callback()
