const vision = require('@google-cloud/vision');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const client = new vision.ImageAnnotatorClient();

async function filterImage(event) {
  const object = event; // in v2, event.data is passed, but sometimes the whole event object. Wait, onObjectFinalized passes CloudEvent<StorageObjectData>
  const filePath = object.name;
  const bucketName = object.bucket;

  if (!filePath) return null;

  // Sadece ilgili klasörleri denetle (profil veya maç resimleri)
  if (!filePath.startsWith('profile_images/') && !filePath.startsWith('match_images/')) {
    return null;
  }

  const gcsUri = `gs://${bucketName}/${filePath}`;

  try {
    const [result] = await client.safeSearchDetection(gcsUri);
    const detections = result.safeSearchAnnotation;

    if (!detections) return null;

    // +18, şiddet veya racy durumlarını kontrol et
    const isAdult = detections.adult === 'LIKELY' || detections.adult === 'VERY_LIKELY';
    const isViolence = detections.violence === 'LIKELY' || detections.violence === 'VERY_LIKELY';
    const isRacy = detections.racy === 'VERY_LIKELY';

    if (isAdult || isViolence || isRacy) {
      console.log(`Inappropriate image detected at ${gcsUri}. Deleting...`);
      
      const bucket = getStorage().bucket(bucketName);
      await bucket.file(filePath).delete();

      // Profil resmi ise veritabanından URL'yi temizle
      if (filePath.startsWith('profile_images/')) {
        const uid = filePath.split('/')[1].split('.')[0];
        const db = getFirestore();
        await db.collection('users').doc(uid).update({
          avatarUrl: null,
          avatarData: '0',
          avatarType: 'icon'
        }).catch(err => console.error("Error updating user document:", err));
      }
      
      return { action: 'deleted', reason: 'inappropriate_content' };
    }
  } catch (error) {
    console.error('Error during Vision API safe search:', error);
  }

  return { action: 'passed' };
}

module.exports = { filterImage };
