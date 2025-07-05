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

// New HTTP function that doesn't require authentication
exports.sendPillNotificationPublic = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  // Only allow POST
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }
  
  try {
    const { token, title, body, data, apiKey } = req.body;
    
    // Very basic API key validation - in production use a more secure method
    const validApiKey = "amanak_pill_notification_key_2025";
    
    if (apiKey !== validApiKey) {
      console.error('Invalid API key');
      res.status(403).send({ error: 'Unauthorized' });
      return;
    }
    
    if (!token) {
      console.error('No FCM token provided');
      res.status(400).send({ error: 'Token is required' });
      return;
    }
    
    // Create high priority message
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
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
    
    console.log(`Sending pill notification via public endpoint: ${title} - ${body}`);
    
    // Send the notification
    const response = await admin.messaging().send(message);
    console.log(`Successfully sent pill notification: ${response}`);
    
    // Store notification in Firestore for tracking
    await admin.firestore().collection('sent_notifications').add({
      token: token,
      title: title,
      body: body,
      data: data,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      messageId: response,
      method: 'public_endpoint'
    });
    
    res.status(200).send({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending pill notification:', error);
    res.status(500).send({ error: error.message });
  }
});

// Dedicated function for pill taken notifications
exports.pillTakenNotification = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  // Only allow POST
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }
  
  try {
    const { token, elderName, pillName, guardianId, apiKey } = req.body;
    
    // Very basic API key validation
    const validApiKey = "amanak_pill_notification_key_2025";
    
    if (apiKey !== validApiKey) {
      console.error('Invalid API key');
      res.status(403).send({ error: 'Unauthorized' });
      return;
    }
    
    if (!token) {
      console.error('No FCM token provided');
      res.status(400).send({ error: 'Token is required' });
      return;
    }
    
    // Prepare notification content
    const title = "Medicine Taken";
    const body = `${elderName} marked ${pillName} as taken.`;
    
    // Create high priority message
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: 'pill_taken',
        pillName: pillName || '',
        elderName: elderName || '',
        timestamp: Date.now().toString(),
      },
      android: {
        priority: "high",
        ttl: 60 * 1000, // 1 minute expiration
        notification: {
          channel_id: "taken_pill_channel", // Specific channel for taken pills
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
    
    console.log(`Sending pill taken notification: ${elderName} took ${pillName}`);
    
    // Send the notification
    const response = await admin.messaging().send(message);
    console.log(`Successfully sent pill taken notification: ${response}`);
    
    // Store notification in Firestore for tracking
    const notificationRef = await admin.firestore().collection('sent_notifications').add({
      token: token,
      title: title,
      body: body,
      data: {
        type: 'pill_taken',
        pillName: pillName || '',
        elderName: elderName || '',
      },
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      messageId: response,
      method: 'pill_taken_endpoint'
    });
    
    // Also store in guardian's notifications collection
    if (guardianId) {
      await admin.firestore().collection('users').doc(guardianId).collection('notifications').add({
        title: title,
        message: body,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        type: 'pill_taken',
        data: {
          pillName: pillName || '',
          elderName: elderName || '',
        },
      });
    }
    
    res.status(200).send({ success: true, messageId: response, notificationId: notificationRef.id });
  } catch (error) {
    console.error('Error sending pill taken notification:', error);
    res.status(500).send({ error: error.message });
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
      
      const { token, title, body, data, pillName, elderName, type, guardianId } = notificationData;
      
      if (!token) {
        console.error('No FCM token provided in notification data');
        return null;
      }
      
      // Create high priority message
      const message = {
        token: token,
        notification: {
          title: title || "Medication Reminder",
          body: body || "Medication notification",
        },
        data: data || {
          type: type || 'pill_taken',
          pillName: pillName || '',
          elderName: elderName || '',
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
      
      console.log(`Sending pill notification from Firestore trigger: ${title || "Medication Reminder"}`);
      
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
