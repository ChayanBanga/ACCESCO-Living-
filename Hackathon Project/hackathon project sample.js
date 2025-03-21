/* script.js */
document.getElementById('studentForm').addEventListener('submit', function(event) {
    event.preventDefault();

    const instituteName = document.getElementById('instituteName').value;
    const studentName = document.getElementById('studentName').value;
    const rollNumber = document.getElementById('rollNumber').value;
    const subjects = document.getElementById('subjects').value.split(',');
    const marks = document.getElementById('marks').value.split(',');
    const studentImage = document.getElementById('studentImage').files[0];

    if (subjects.length !== marks.length) {
        alert("Number of subjects and marks must match.");
        return;
    }

    const reader = new FileReader();
    reader.onload = function(e) {
        displayStudentData({
            instituteName,
            studentName,
            rollNumber,
            subjects,
            marks,
            imageUrl: e.target.result
        });
    };

    if (studentImage) {
        reader.readAsDataURL(studentImage);
    } else {
        displayStudentData({
            instituteName,
            studentName,
            rollNumber,
            subjects,
            marks,
            imageUrl: 'placeholder.png' //replace with a placeholder image.
        });
    }

    document.getElementById('studentForm').reset();
});

function displayStudentData(student) {
    const studentList = document.getElementById('studentList');
    const studentItem = document.createElement('div');
    studentItem.classList.add('student-item');

    studentItem.innerHTML = `
        <img src="${student.imageUrl}" alt="${student.studentName}">
        <div>
            <h3>${student.studentName} (${student.rollNumber})</h3>
            <p>Institute: ${student.instituteName}</p>
            <p>Subjects: ${student.subjects.map((subject, index) => `${subject}: ${student.marks[index]}`).join(', ')}</p>
        </div>
    `;

    studentList.appendChild(studentItem);
}