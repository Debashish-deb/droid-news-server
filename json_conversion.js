const fs = require('fs');

function convertJsonFormat(outputFilePath, inputFilePath = 'data.json') {
  try {
    const rawData = fs.readFileSync(inputFilePath, 'utf-8');
    const data = JSON.parse(rawData);

    const newspapers = [];

    // Function to extract data safely
    const extractData = (item) => ({
      id: item.id || null,
      name: item.name || null,
      snippet: item.snippet || item.description || null,
      url: item.url || null,
      tags: item.tags || [],
      logo: item.logo || null,
      logo_small: item.logo_small || null,
      logo_medium: item.logo_medium || null
    });

    // Process newspapers
    if (data.newspapers) {
      data.newspapers.forEach(item => {
        newspapers.push(extractData(item));
      });
    }

    // Process magazines
    if (data.magazines) {
      data.magazines.forEach(item => {
        newspapers.push(extractData(item));
      });
    }

    const outputData = { newspapers: newspapers };

    fs.writeFileSync(outputFilePath, JSON.stringify(outputData, null, 4), 'utf-8');
    console.log(`Conversion complete. The converted data has been saved to '${outputFilePath}'`);

  } catch (error) {
    console.error('An error occurred:', error);
  }
}

// Usage
const outputFile = 'converted_data.json';
convertJsonFormat(outputFile);