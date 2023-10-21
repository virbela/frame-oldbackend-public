const url = require("url");
const axios = require("axios");
const express = require("express");
const { getAuth, getFirestore } = require("../libs/database");
const { FieldPath } = require("firebase-admin/firestore");
const jwt = require("jsonwebtoken");
const jwksClient = require("jwks-rsa");
const { readFileSync } = require("fs");
const path = require("path");

const router = express.Router();

const client = jwksClient({
  jwksUri: "https://login.microsoftonline.com/common/discovery/v2.0/keys",
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, function (_err, key) {
    const signingKey = key.publicKey || key.rsaPublicKey;
    callback(null, signingKey);
  });
}
/**
 * @swagger
 * /auth/firebase/msteams:
 *   post:
 *     tags:
 *       - Authentication
 *     summary: MSTeams Authentication
 *     description: Submit token from msteams to firebase in order to validate authentication from MSTeams Interface
 *     requestBody:
 *       required: true
 *       content:
 *         application/x-www-form-urlencoded:
 *           schema:
 *             type: object
 *             properties:
 *               token:
 *                 type: string
 *                 description: msteams token to submit to firebase
 *                 default: "TBD"
 *             required:
 *               - token
 *     responses:
 *       '200':
 *         description: Successfully connected
 *       '400':
 *         description: Invalid token specified
 *       '403':
 *         description: Failed to create a new token
 */
router.post("/firebase/msteams", async function ({ body: { token } }, res) {
  jwt.verify(token, getKey, {}, function (_err, validToken) {
    console.log("Valid token:", validToken);

    if (
      !validToken ||
      !validToken.email ||
      !validToken.name ||
      !validToken.upn
    ) {
      return res.status(400).send("Invalid token specified");
    }
    //Authorize/Assign the user's oid as a firebase uerid
    // Generate firebase token to send to client (for login)
    getAuth()
      .createCustomToken(validToken.oid)
      .then((token) => {
        res.json({
          token,
          username: validToken.name,
          email: validToken.email || validToken.upn,
        });
      })
      .catch(() => {
        console.log.bind(console, "Error creating custom token:");
        return res.status(403).send({ urlFound: false });
      });
  });
});

module.exports = router;
