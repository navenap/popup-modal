function doGet(e) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("questions");
  const data = sheet.getDataRange().getValues();

  const headers = data[0];
  const rows = data.slice(1);

  const result = rows.map(row => {
    let obj = {};
    headers.forEach((h, i) => obj[h] = row[i]);
    return obj;
  });

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}


function doPost(e) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("responses");

  const data = JSON.parse(e.postData.contents);

  const timestamp = new Date();

  const rows = data.answers.map(ans => [
    timestamp,
    data.device_serial,
    data.username,
    ans.question_id,
    ans.answer
  ]);

  sheet.getRange(sheet.getLastRow() + 1, 1, rows.length, rows[0].length)
       .setValues(rows);

  if (!data.answers || data.answers.length === 0) {
    return ContentService
      .createTextOutput(JSON.stringify({ status: "error", message: "No answers provided" }))
      .setMimeType(ContentService.MimeType.JSON);
  }

  return ContentService
    .createTextOutput(JSON.stringify({ status: "success" }))
    .setMimeType(ContentService.MimeType.JSON);

}
