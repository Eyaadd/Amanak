const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Cloud Function to send FCM notifications with high priority
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

    // Prepare the message with high priority settings
    const message = {
      token: token,
      notification: notification,
      data: messageData || {},
      android: {
        priority: "high",
        ttl: 60 * 1000, // 1 minute expiration
        notification: {
          channel_id: "high_importance_channel",
          priority: "high",
          default_vibrate_timings: true,
          default_sound: true,
        },
      },
      apns: {
        headers: {
          "apns-priority": "10", // Immediate delivery
          "apns-push-type": "alert"
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            content_available: 1,
            mutable_content: 1,
            priority: 10
          },
        },
      },
      webpush: {
        headers: {
          Urgency: "high"
        }
      }
    };

    // Send the message with high priority
    console.log("Sending notification with high priority:", message);
    const response = await admin.messaging().send(message);
    console.log("Successfully sent message:", response);
    
    return { success: true, messageId: response };
  } catch (error) {
    console.error("Error sending notification:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Firestore trigger to send pill notifications immediately
exports.sendPillNotification = functions.firestore
  .onDocumentCreated("pill_notifications/{notificationId}", async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) {
        console.log('No data associated with the event');
        return null;
      }
      
      const notificationData = snapshot.data();
      
      if (!notificationData || notificationData.processed === true) {
        console.log('Notification already processed or invalid data');
        return null;
      }
      
      const { token, title, body, pillName, elderName, type, guardianId } = notificationData;
      
      if (!token) {
        console.error('No FCM token provided in notification data');
        return null;
      }
      
      // Create high priority message
      const message = {
        token: token,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: type || 'pill_taken',
          pillName: pillName || '',
          elderName: elderName || '',
          title: title,
          body: body,
          timestamp: Date.now().toString(),
        },
        android: {
          priority: "high",
          ttl: 60 * 1000, // 1 minute expiration
          notification: {
            channel_id: "high_importance_channel",
            priority: "high",
            default_vibrate_timings: true,
            default_sound: true,
          },
        },
        apns: {
          headers: {
            "apns-priority": "10", // Immediate delivery
            "apns-push-type": "alert"
          },
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              content_available: 1,
              mutable_content: 1,
            },
          },
        },
      };
      
      console.log(`Sending pill notification to ${guardianId}: ${title} - ${body}`);
      
      // Send the notification
      const response = await admin.messaging().send(message);
      
      // Mark as processed
      await snapshot.ref.update({ 
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response
      });
      
      console.log(`Successfully sent pill notification: ${response}`);
      return response;
    } catch (error) {
      console.error('Error sending pill notification:', error);
      
      // Mark as failed if we have a snapshot reference
      if (event.data && event.data.ref) {
        await event.data.ref.update({ 
          processed: false,
          error: error.message,
          errorAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      
      return null;
    }
  });
