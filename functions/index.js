const functions = require("firebase-functions");

// Optional (you already had this)
const {setGlobalOptions} = require("firebase-functions");
setGlobalOptions({maxInstances: 10});

// ✅ YOUR FUNCTION
exports.sendAssignmentEmail = functions.https.onCall(async (data, context) => {
  console.log("📩 FUNCTION CALLED");
  console.log("Incoming data:", data);

  const {toEmail, driverName, transferNo, fromStore, toStore} = data;

  // For now just log instead of sending email
  console.log("To:", toEmail);
  console.log("Driver:", driverName);
  console.log("Transfer:", transferNo);

  return {
    success: true,
    message: "Function executed locally",
  };
});