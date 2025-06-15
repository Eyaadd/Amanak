const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Cloud Function to send FCM notifications
exports.sendNotification = functions.https.onCall(async (data, context) => {
  // Check if the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  try {
    const { token, notification, data: messageData } = data;

    if (!token) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a valid FCM token."
      );
    }

    // Prepare the message
    const message = {
      token: token,
      notification: notification,
      data: messageData || {},
      android: {
        priority: "high",
        notification: {
          channel_id: "high_importance_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    // Send the message
    const response = await admin.messaging().send(message);
    console.log("Successfully sent message:", response);
    
    return { success: true, messageId: response };
  } catch (error) {
    console.error("Error sending notification:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});
