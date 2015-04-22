should = require "should"
request = require "supertest"
server = require "../../lib/server"
Channel = require("../../lib/model/channels").Channel
Mediator = require("../../lib/model/mediators").Mediator
testUtils = require "../testUtils"
auth = require("../testUtils").auth

describe "API Integration Tests", ->
  describe 'Mediators REST API testing', ->

    mediator1 =
      urn: "urn:uuid:EEA84E13-1C92-467C-B0BD-7C480462D1ED"
      version: "1.0.0"
      name: "Save Encounter Mediator"
      description: "A mediator for testing"
      endpoints: [
        {
          name: 'Save Encounter'
          host: 'localhost'
          port: '8005'
          type: 'http'
        }
      ]
      defaultChannelConfig: [
        name: "Save Encounter"
        urlPattern: "/encounters"
        type: 'http'
        allow: []
        routes: [
          {
            name: 'Save Encounter'
            host: 'localhost'
            port: '8005'
            type: 'http'
          }
        ]
      ]

    mediator2 =
      urn: "urn:uuid:25ABAB99-23BF-4AAB-8832-7E07E4EA5902"
      version: "0.8.2"
      name: "Patient Mediator"
      description: "Another mediator for testing"
      endpoints: [
        {
          name: 'Patient'
          host: 'localhost'
          port: '8006'
          type: 'http'
        }
      ]

    authDetails = {}

    before (done) ->
      auth.setupTestUsers (err) ->
        return done err if err
        server.start apiPort: 8080, done

    after (done) ->
      server.stop -> auth.cleanupTestUsers done

    beforeEach ->
      authDetails = auth.getAuthDetails()

    afterEach (done) -> Mediator.remove {}, -> Channel.remove {}, done

    describe '*getAllMediators()', ->
      it 'should fetch all mediators', (done) ->
        new Mediator(mediator1).save ->
          new Mediator(mediator2).save ->
            request("https://localhost:8080")
              .get("/mediators")
              .set("auth-username", testUtils.rootUser.email)
              .set("auth-ts", authDetails.authTS)
              .set("auth-salt", authDetails.authSalt)
              .set("auth-token", authDetails.authToken)
              .expect(200)
              .end (err, res) ->
                if err
                  done err
                else
                  res.body.length.should.be.eql 2
                  done()

      it 'should not allow non root user to fetch mediators', (done) ->
        request("https://localhost:8080")
          .get("/mediators")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(403)
          .end (err, res) ->
            if err
              done err
            else
              done()

    describe '*getMediator()', ->
      it 'should fetch mediator', (done) ->
        new Mediator(mediator1).save ->
          request("https://localhost:8080")
            .get("/mediators/#{mediator1.urn}")
            .set("auth-username", testUtils.rootUser.email)
            .set("auth-ts", authDetails.authTS)
            .set("auth-salt", authDetails.authSalt)
            .set("auth-token", authDetails.authToken)
            .expect(200)
            .end (err, res) ->
              if err
                done err
              else
                res.body.urn.should.be.exactly mediator1.urn
                done()

      it 'should return status 404 if not found', (done) ->
        request("https://localhost:8080")
          .get("/mediators/#{mediator1.urn}")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(404)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should not allow non root user to fetch mediator', (done) ->
        request("https://localhost:8080")
          .get("/mediators/#{mediator1.urn}")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(403)
          .end (err, res) ->
            if err
              done err
            else
              done()

    describe '*addMediator()', ->
      it 'should return 201', (done) ->
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(mediator1)
          .expect(201)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should not allow non root user to add mediator', (done) ->
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(mediator1)
          .expect(403)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should add the mediator to the mediators collection', (done) ->
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(mediator1)
          .expect(201)
          .end (err, res) ->
            if err
              done err
            else
              Mediator.findOne { urn: mediator1.urn }, (err, res) ->
                return done err if err
                should.exist(res)
                done()

      it 'should create a channel with the default channel config supplied', (done) ->
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(mediator1)
          .expect(201)
          .end (err, res) ->
            if err
              done err
            else
              Channel.findOne { name: mediator1.defaultChannelConfig[0].name }, (err, res) ->
                return done err if err
                should.exist(res)
                done()

      it 'should not do anything if the mediator already exists and the version number is equal', (done) ->
        updatedMediator =
          urn: "urn:uuid:EEA84E13-1C92-467C-B0BD-7C480462D1ED"
          version: "1.0.0"
          name: "Updated Encounter Mediator"
        new Mediator(mediator1).save ->
          request("https://localhost:8080")
            .post("/mediators")
            .set("auth-username", testUtils.rootUser.email)
            .set("auth-ts", authDetails.authTS)
            .set("auth-salt", authDetails.authSalt)
            .set("auth-token", authDetails.authToken)
            .send(updatedMediator)
            .expect(201)
            .end (err, res) ->
              if err
                done err
              else
                Mediator.find { urn: mediator1.urn }, (err, res) ->
                  return done err if err
                  res.length.should.be.exactly 1
                  res[0].name.should.be.exactly mediator1.name
                  done()

      it 'should not do anything if the mediator already exists and the version number is less-than', (done) ->
        updatedMediator =
          urn: "urn:uuid:EEA84E13-1C92-467C-B0BD-7C480462D1ED"
          version: "0.9.5"
          name: "Updated Encounter Mediator"
        new Mediator(mediator1).save ->
          request("https://localhost:8080")
            .post("/mediators")
            .set("auth-username", testUtils.rootUser.email)
            .set("auth-ts", authDetails.authTS)
            .set("auth-salt", authDetails.authSalt)
            .set("auth-token", authDetails.authToken)
            .send(updatedMediator)
            .expect(201)
            .end (err, res) ->
              if err
                done err
              else
                Mediator.find { urn: mediator1.urn }, (err, res) ->
                  return done err if err
                  res.length.should.be.exactly 1
                  res[0].name.should.be.exactly mediator1.name
                  done()

      it 'should update the mediator if the mediator already exists and the version number is greater-than', (done) ->
        updatedMediator =
          urn: "urn:uuid:EEA84E13-1C92-467C-B0BD-7C480462D1ED"
          version: "1.0.1"
          name: "Updated Encounter Mediator"
        new Mediator(mediator1).save ->
          request("https://localhost:8080")
            .post("/mediators")
            .set("auth-username", testUtils.rootUser.email)
            .set("auth-ts", authDetails.authTS)
            .set("auth-salt", authDetails.authSalt)
            .set("auth-token", authDetails.authToken)
            .send(updatedMediator)
            .expect(201)
            .end (err, res) ->
              if err
                done err
              else
                Mediator.find { urn: mediator1.urn }, (err, res) ->
                  return done err if err
                  res.length.should.be.exactly 1
                  res[0].name.should.be.exactly updatedMediator.name
                  done()

      it 'should reject mediators without a UUID', (done) ->
        invalidMediator =
          version: "0.8.2"
          name: "Patient Mediator"
          description: "Invalid mediator for testing"
          endpoints: [
            {
              name: 'Patient'
              host: 'localhost'
              port: '8006'
              type: 'http'
            }
          ]
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(invalidMediator)
          .expect(400)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should reject mediators without a name', (done) ->
        invalidMediator =
          urn: "urn:uuid:CA5B32BC-87CB-46A5-B9C7-AAF03500989A"
          version: "0.8.2"
          description: "Invalid mediator for testing"
          endpoints: [
            {
              name: 'Patient'
              host: 'localhost'
              port: '8006'
              type: 'http'
            }
          ]
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(invalidMediator)
          .expect(400)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should reject mediators without a version number', (done) ->
        invalidMediator =
          urn: "urn:uuid:CA5B32BC-87CB-46A5-B9C7-AAF03500989A"
          name: "Patient Mediator"
          description: "Invalid mediator for testing"
          endpoints: [
            {
              name: 'Patient'
              host: 'localhost'
              port: '8006'
              type: 'http'
            }
          ]
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(invalidMediator)
          .expect(400)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should reject mediators with an invalid SemVer version number (x.y.z)', (done) ->
        invalidMediator =
          urn: "urn:uuid:CA5B32BC-87CB-46A5-B9C7-AAF03500989A"
          name: "Patient Mediator"
          version: "0.8"
          description: "Invalid mediator for testing"
          endpoints: [
            {
              name: 'Patient'
              host: 'localhost'
              port: '8006'
              type: 'http'
            }
          ]
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(invalidMediator)
          .expect(400)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should reject mediators with no endpoints specified', (done) ->
        invalidMediator =
          urn: "urn:uuid:CA5B32BC-87CB-46A5-B9C7-AAF03500989A"
          name: "Patient Mediator"
          version: "0.8.2"
          description: "Invalid mediator for testing"
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(invalidMediator)
          .expect(400)
          .end (err, res) ->
            if err
              done err
            else
              done()

      it 'should reject mediators with an empty endpoints array specified', (done) ->
        invalidMediator =
          urn: "urn:uuid:CA5B32BC-87CB-46A5-B9C7-AAF03500989A"
          name: "Patient Mediator"
          version: "0.8.2"
          description: "Invalid mediator for testing"
          endpoints: []
        request("https://localhost:8080")
          .post("/mediators")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send(invalidMediator)
          .expect(400)
          .end (err, res) ->
            if err
              done err
            else
              done()

    describe "*removeMediator", ->
      it  "should remove an mediator with specified urn", (done) ->

        mediatorDelete =
          urn: "urn:uuid:EEA84E13-2M74-467C-UD7F-7C480462D1DF"
          version: "1.0.0"
          name: "Test Mediator"
          description: "A mediator for testing"
          endpoints: [
            {
              name: 'Save Encounter'
              host: 'localhost'
              port: '6000'
              type: 'http'
            }
          ]
          defaultChannelConfig: [
            name: "Test Mediator"
            urlPattern: "/test"
            type: 'http'
            allow: []
            routes: [
              {
                name: 'Test Route'
                host: 'localhost'
                port: '9000'
                type: 'http'
              }
            ]
          ]

        mediator = new Mediator mediatorDelete
        mediator.save (error, mediator) ->
          should.not.exist(error)
          Mediator.count (err, countBefore) ->
            request("https://localhost:8080")
              .del("/mediators/" + mediator.urn)
              .set("auth-username", testUtils.rootUser.email)
              .set("auth-ts", authDetails.authTS)
              .set("auth-salt", authDetails.authSalt)
              .set("auth-token", authDetails.authToken)
              .expect(200)
              .end (err, res) ->
                if err
                  done err
                else
                  Mediator.count (err, countAfter) ->
                    Mediator.findOne { urn: mediator.urn }, (error, notFoundDoc) ->
                      (notFoundDoc == null).should.be.true
                      (countBefore - 1).should.equal countAfter
                      done()

      it  "should not allow a non admin user to remove a mediator", (done) ->

        request("https://localhost:8080")
          .del("/mediators/urn:uuid:EEA84E13-2M74-467C-UD7F-7C480462D1DF")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(403)
          .end (err, res) ->
            if err
              done err
            else
              done()
