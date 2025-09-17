const express = require("express");
const admin = require("firebase-admin");
const cron = require("node-cron");
const path = require("path");
const fs = require("fs");

const app = express();

// Initialize Firebase with explicit path
try {
  const serviceAccount = require(path.join(__dirname, "riceguardapp-c3931-b3a452db34a8.json"));
  
  console.log("Service account project_id:", serviceAccount.project_id);
  console.log("Service account client_email:", serviceAccount.client_email);
  
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id,
      storageBucket: `${serviceAccount.project_id}.appspot.com`,
    });
  }
  
  console.log("✅ Firebase initialized successfully");
} catch (error) {
  console.error("❌ Firebase initialization failed:", error.message);
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Local logging function
function saveLogLocally(logData) {
  const logFile = path.join(__dirname, "deleted_pins_log.json");
  let logs = [];
  
  try {
    if (fs.existsSync(logFile)) {
      logs = JSON.parse(fs.readFileSync(logFile, 'utf8'));
    }
  } catch (error) {
    console.log("Creating new log file");
  }
  
  logs.push({
    id: new Date().toISOString(),
    timestamp: new Date().toISOString(),
    ...logData
  });
  
  fs.writeFileSync(logFile, JSON.stringify(logs, null, 2));
}

async function deleteOldPins() {
  try {
    const now = admin.firestore.Timestamp.now();
    const cutoff = new Date(now.toDate().getTime() - 30 * 24 * 60 * 60 * 1000); // 30 วัน

    const snapshot = await db
      .collection("pins")
      .where("lastUpdated", "<", cutoff)
      .get();

    if (snapshot.empty) {
      console.log("✅ No outdated pins found.");
      return;
    }

    const deletions = [];

    for (const doc of snapshot.docs) {
      const originalData = doc.data();
      const docId = doc.id;

      if (originalData.imageUrl) {
        const match = originalData.imageUrl.match(/\/o\/(.*?)\?/);
        if (match && match[1]) {
          const imagePath = decodeURIComponent(match[1]);
          try {
            await bucket.file(imagePath).delete();
            console.log(`🗑️ Deleted image: ${imagePath}`);
          } catch (err) {
            console.warn(
              `⚠️ Failed to delete image ${imagePath}: ${err.message}`
            );
          }
        }
      }

      // ลบ imageUrl ก่อนเขียน log
      const cleanedData = { ...originalData };
      delete cleanedData.imageUrl;

      // Save to both Firestore and local file
      const timestampId = new Date().toISOString().replace(/[:.]/g, "-");
      
      try {
        await db.collection("deleted_pins_log").doc(timestampId).set(cleanedData);
      } catch (error) {
        console.warn("Failed to save to Firestore, saving locally:", error.message);
      }
      
      // Always save locally as backup
      saveLogLocally(cleanedData);

      deletions.push(doc.ref.delete());
    }

    await Promise.all(deletions);
    console.log(`✅ Deleted ${deletions.length} pin(s) and image(s).`);
  } catch (error) {
    console.error("❌ Error deleting pins:", error);
  }
}

// ✅ Cron Job: รันทุกวันตี 1
cron.schedule("0 1 * * *", () => {
  console.log("⏰ Running scheduled auto-delete...");
  deleteOldPins();
});

// ✅ Root route
app.get("/", (req, res) => {
  res.send(`
    <h2>Autodelete Server</h2>
    <p><a href="/logs">View Logs</a></p>
    <p>Auto-delete runs daily at 1:00 AM</p>
  `);
});

// ✅ Route สำหรับดู logs บนเว็บ
app.get("/logs", async (req, res) => {
  try {
    // Try Firestore first
    try {
      const snapshot = await db.collection("deleted_pins_log").get();
      const logs = [];
      
      snapshot.forEach(doc => {
        logs.push({
          id: doc.id,
          ...doc.data()
        });
      });
      
      return res.json({ 
        count: logs.length, 
        logs: logs,
        status: "success",
        source: "firestore"
      });
    } catch (firestoreError) {
      console.log("Firestore failed, trying local file:", firestoreError.message);
    }
    
    // Fallback to local file
    const logFile = path.join(__dirname, "deleted_pins_log.json");
    
    if (fs.existsSync(logFile)) {
      const logs = JSON.parse(fs.readFileSync(logFile, 'utf8'));
      res.json({ 
        count: logs.length, 
        logs: logs,
        status: "success",
        source: "local file (firestore unavailable)"
      });
    } else {
      res.json({ 
        count: 0, 
        logs: [],
        status: "success",
        message: "No logs found in either Firestore or local file"
      });
    }
  } catch (error) {
    console.error("Error reading logs:", error);
    res.status(500).json({ 
      error: error.message,
      status: "error"
    });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});
