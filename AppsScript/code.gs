function doGet(e) {

  const deviceSerial = e.parameter.device_serial;
  const installDate = e.parameter.install_date;

  const qSheet = SpreadsheetApp
    .getActiveSpreadsheet()
    .getSheetByName("questions");

  const rSheet = SpreadsheetApp
    .getActiveSpreadsheet()
    .getSheetByName("responses");

  const qData = qSheet.getDataRange().getValues();
  const rData = rSheet.getDataRange().getValues();

  const qHeaders = qData[0];
  const qRows = qData.slice(1);

  const rRows = rData.slice(1);

  // Calculate current day
  const install = new Date(installDate);
  const today = new Date();

  const diffTime = today - install;

  const dayNumber =
    Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;

  // Find today's question
  let todayQuestion = null;

  qRows.forEach(row => {

    let obj = {};

    qHeaders.forEach((h, i) => obj[h] = row[i]);

    if (Number(obj.day) === dayNumber) {
      todayQuestion = obj;
    }
  });

  if (!todayQuestion) {
    return ContentService
      .createTextOutput(JSON.stringify([]))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Check already answered
  const alreadyAnswered = rRows.some(row =>
    row[1] === deviceSerial &&
    String(row[3]) === String(todayQuestion.id)
  );

  if (alreadyAnswered) {
    return ContentService
      .createTextOutput(JSON.stringify([]))
      .setMimeType(ContentService.MimeType.JSON);
  }

  return ContentService
    .createTextOutput(JSON.stringify([todayQuestion]))
    .setMimeType(ContentService.MimeType.JSON);
}


function doPost(e) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("responses");
  const data = JSON.parse(e.postData.contents);

  if (!data.answers || data.answers.length === 0) {
    return ContentService
      .createTextOutput(JSON.stringify({ status: "error", message: "No answers provided" }))
      .setMimeType(ContentService.MimeType.JSON);
  }

  const existing = sheet.getDataRange().getValues();

  const rowsToInsert = [];
  const timestamp = new Date();

  data.answers.forEach(ans => {
    const alreadyAnswered = existing.some(row =>
      row[1] === data.device_serial && row[3] == ans.question_id
    );

    if (!alreadyAnswered) {
      rowsToInsert.push([
        timestamp,
        data.device_serial,
        data.username,
        ans.question_id,
        ans.answer
      ]);
    }
  });

  if (rowsToInsert.length > 0) {
    sheet.getRange(sheet.getLastRow() + 1, 1, rowsToInsert.length, rowsToInsert[0].length)
         .setValues(rowsToInsert);
  }

  return ContentService
    .createTextOutput(JSON.stringify({ status: "success" }))
    .setMimeType(ContentService.MimeType.JSON);
}
