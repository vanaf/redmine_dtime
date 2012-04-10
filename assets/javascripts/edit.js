
//jquery code for the comment dialog

//could not use $ since itis conflicting with prototype
//hence did a noconflci and used jQuery object
jQuery.noConflict();
var comment_row = 0;
var changed = false;
jQuery(document).ready(function() {
//jQuery(function() {
	var e_comments = jQuery( "#_edit_comments_" );

	jQuery( "#comment-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,
		buttons: {
			"Ok": function() {
					var edits = jQuery('img[id="_comments_img_"]');
					var comments = jQuery('input[name="time_entry[][comments]"]');
					edits[comment_row].title = e_comments.val();
					comments[comment_row].value = e_comments.val();
					jQuery( this ).dialog( "close" );
					
					//unregister this event since this is showing a 'don't leave' message
					//loosk like this is not supported in Opera
					window.onbeforeunload = null;
			},
			Cancel: function() {
				jQuery( this ).dialog( "close" );
			}
		}
	});
});

function dateChanged(elem) {
        var editUrl = document.getElementById("edit_url").value;
	if(!changed||confirm("Load "+elem.value+"? (Lost current changes)")){
		performAction(editUrl);
	}
}

function showComment(row) {
	var images = jQuery( 'img[id="_comments_img_"]' );
	var width = 200;
	var height = 250;
	var posX = 0;
	var posY = 0;
	var i = row - 1;
	var currImage = images[i];

	var projDropdowns = jQuery('select[name="time_entry[][project_id]"]');
	var issDropdowns = jQuery('select[name="time_entry[][issue_id]"]');
	var actDropdowns = jQuery('select[name="time_entry[][activity_id]"]');
	var comments = jQuery('input[name="time_entry[][comments]"]');
	//set the row which is modified
	comment_row = i;
	jQuery( "#_edit_comments_" ).val(comments[i].value);
	jQuery( "#_edit_comm_proj_" ).html(projDropdowns[i].selectedIndex >= 0 ? 
		projDropdowns[i].options[projDropdowns[i].selectedIndex].text : '');
	jQuery( "#_edit_comm_iss_" ).html(issDropdowns[i].selectedIndex >= 0 ?
		issDropdowns[i].options[issDropdowns[i].selectedIndex].text : '');
	jQuery( "#_edit_comm_act_" ).html(actDropdowns[i].selectedIndex >= 0 ?
		actDropdowns[i].options[actDropdowns[i].selectedIndex].text : '');
	
	posX = jQuery(currImage).offset().left - jQuery(document).scrollLeft() - width + jQuery(currImage).outerWidth();
	posY = jQuery(currImage).offset().top - jQuery(document).scrollTop() + jQuery(currImage).outerHeight();
	jQuery("#comment-dlg").dialog({width:width, height:height ,position:[posX, posY]});
	jQuery( "#comment-dlg" ).dialog( "open" );
}

function projectChanged(projDropdown, row){
	changed = true;
	var id = projDropdown.options[projDropdown.selectedIndex].value;
	var fmt = 'text';
	var issDropdown = document.getElementsByName("time_entry[][issue_id]");
	var actDropdown = document.getElementsByName("time_entry[][activity_id]");
	var closedIssueInd = document.getElementById("closed_issue_ind").checked;
	var issUrl = document.getElementById("getissues_url").value;
	var actUrl = document.getElementById("getactivities_url").value;
        var date = document.getElementById("date").value;

	var uid = document.getElementById("user_id").value;
	new Ajax.Updater('issue_container', issUrl,{
        parameters: closedIssueInd ? { project_id: id, user_id: uid, format:fmt, closed_issue_ind: closedIssueInd, date:date} :
		{ project_id: id, user_id: uid, format:fmt, date:date},
        onSuccess: function(request){ updateDropdown(request.responseText, row, issDropdown, true, true, true,null) }
       });
	new Ajax.Updater('activity_container', actUrl, {
        parameters: { project_id: id, user_id: uid, format:fmt},
        onSuccess: function(request){ updateDropdown(request.responseText, row, actDropdown, false, false,false, null) }
       });
}

function reloadIssues(closedIssueInd){
	var fmt = 'text';
	var projDropdowns = document.getElementsByName("time_entry[][project_id]");
	var date = document.getElementById("date").value;
	var uid = document.getElementById("user_id").value;
	var url = document.getElementById("getissues_url").value;
	console.log(date);
	var i, id, j=0;
	var project_ids = new Array();
	if(projDropdowns){
		for (i=0; i < projDropdowns.length; i++){
			id = projDropdowns[i].options[projDropdowns[i].selectedIndex].value;
			if(id != ''){
				project_ids[j] = id;
				j++;
			}
		}
	}
	if(project_ids.length > 0){
		new Ajax.Updater('issue_container', url, {
        parameters: closedIssueInd ? { 'project_ids[]': project_ids, user_id: uid, closed_issue_ind: closedIssueInd, date: date, format:fmt} :
		{ 'project_ids[]': project_ids, user_id: uid, date: date, format:fmt},
        onSuccess: function(request){ updateIssDropdowns(request.responseText, projDropdowns) }
       });	   
	}
}

function updateIssDropdowns(itemStr, projDropdowns)
{
	var items = itemStr.split('\n');
	var i, index, itemStr2='', val, text;
	var prev_project_id=0, project_id=0;
	var j, id;
	var issDropdowns = document.getElementsByName("time_entry[][issue_id]");
	for(i=0; i < items.length; i++){
		index = items[i].indexOf(',');
		if(index != -1){
			project_id = items[i].substring(0, index);
			if(prev_project_id != project_id && itemStr2 != ''){
				updateIssueDD(itemStr2, prev_project_id, projDropdowns, issDropdowns);
				itemStr2='';
			}
			itemStr2 += items[i] + '\n';
			prev_project_id = project_id;
		}
	}
	//the last project needs to be updated outside the loop
	updateIssueDD(itemStr2, prev_project_id, projDropdowns, issDropdowns);

}

function updateIssueDD(itemStr, project_id, projDropdowns, issDropdowns)
{
	var proj_id, issue_id;
	if(projDropdowns){
		for (j=0; j < projDropdowns.length; j++){
			proj_id = projDropdowns[j].options[projDropdowns[j].selectedIndex].value;
			if(proj_id != '' && project_id == proj_id){			
				if(issDropdowns[j]){
					issue_id = issDropdowns[j].options[issDropdowns[j].selectedIndex].value;
					updateDropdown(itemStr, j+1, issDropdowns, true, true, true, issue_id);
				}
			}
		}
	}
}

function updateDropdown(itemStr, row, dropdown, showId, needBlankOption, skipFirst, selectedVal)
{
	var items = itemStr.split('\n');
	var selectedValSet = false;
	dropdown[row-1].options.length = 0;
	if(needBlankOption){
		dropdown[row-1].options[0] = new Option( "", "", false, false) 
	}
	var i, index, val, text, start;
	for(i=0; i < items.length; i++){
		index = items[i].indexOf(',');
		if(skipFirst){
			if(index != -1){
				start = index+1;
				index = items[i].indexOf(',', index+1);
			}
		}else{
			start = 0;
		}
		if(index != -1){
			val = items[i].substring(start, index);
			text = items[i].substring(index+1);
			dropdown[row-1].options[needBlankOption ? i+1 : i] = new Option( 
				showId ? val + ' - ' + text : text, val, false, val == selectedVal);
			if(val == selectedVal){
				selectedValSet = true;
			}
		}
	}
	if(selectedVal && !selectedValSet){
		dropdown[row-1].options[needBlankOption ? i+1 : i] = new Option( 
				selectedVal, selectedVal, false, true);
	}
}

function performAction(url)
{
	document.dtime_edit.action = url;
	document.dtime_edit.submit();
}

function addRow(){
	var issueTable = document.getElementById("issueTable");	
	var issueTemplate;
	var saveButton = document.getElementById("dtime_save");
	if(document.getElementById("closed_issue_ind").checked){
		issueTemplate = document.getElementById("closedIssueTemplate");
	}else{
		issueTemplate = document.getElementById("issueTemplate");
	}
	var rowCount = issueTable.rows.length;	
	var row = issueTable.insertRow(rowCount);
	var cellCount = issueTemplate.rows[0].cells.length;
	var i, cell;
	for(i=0; i < cellCount; i++){
		cell = row.insertCell(i);
		cell.innerHTML = issueTemplate.rows[0].cells[i].innerHTML.replace(/__template__/g, '');
		cell.className = issueTemplate.rows[0].cells[i].className;
		cell.align = issueTemplate.rows[0].cells[i].align;
	}
	renameElemProperties(row, 0, rowCount);
	saveButton.disabled = false;
}

function deleteRow(row){
	
	//IE7 doesn't pull up the new elements by getElementsByName
	//var ids = document.getElementsByName("ids" + row + "[]");
	//var hours = document.getElementsByName("hours" + row + "[]");	
	
	var issueTable = document.getElementById("issueTable");
	//since there is already a header row
	var hours = myGetElementsByName(issueTable.rows[row], "input","hours" + row + "[]");
	var ids = myGetElementsByName(issueTable.rows[row], "input","ids" + row + "[]");			
	var rowTotal = 0.0;
	var uid = document.getElementById("user_id");
	var vals = new Array();
	var days = new Array();
	var i = 0, j = 0;
	var fmt = 'text', val;
	var url = document.getElementById("deleterow_url").value;
	
	for(i=0; i< ids.length; i++){
		if (ids[i].value != ''){
			vals[j] = ids[i].value;
			j++;
		}
	}
	
	j = 0;
	for(i=0; i< hours.length; i++){
		//IE doesn't support trim()
		val = hours[i].value.replace(/^\s\s*/, '').replace(/\s\s*$/, '');
		if( val != '' && !isNaN(val)){
			days[j] = i+1;
			j++;
		}
	}
	if (vals.length > 0){
	   	   new Ajax.Updater('issue_container', url, {
        parameters: { 'ids[]': vals, format:fmt, user_id:uid.value},
        onSuccess: function(request){ postDeleteRow(request.responseText, row, days) }
       });
	}
	else{
		postDeleteRow('OK', row, days);
	}
}

function postDeleteRow(result, row, days){
	var issueTable = document.getElementById("issueTable");
	var saveButton = document.getElementById("dtime_save");
	var rowCount = issueTable.rows.length;
	var i;
	//there is a header and a total row always present, so the empty count is 2
	if(result == "OK"){
		//replaee the rows following the deleted row
		for(i=row+1; i < rowCount; i++){
			//replace inner html is not working properly for delete so modify
			// the existing DOM objects
			renameElemProperties(issueTable.rows[i], i, i-1);
		}
		issueTable.deleteRow(row);
		if(rowCount - 1 <= 2){
			saveButton.disabled = true;
		}
		for(i=0; i < days.length; i++){	
			calculateTotal(days[i]);
		}
	}
}

//replace inner html is not working properly, hence decided to
//do the rename proeprties
function renameElemProperties(row, index, newIndex){
	var cellCount = row.cells.length;
	var i;
	for(i=0; i < cellCount; i++){
		renameCellIDs(row.cells[i], index, newIndex);
	}
	row.className = (newIndex+1)%2 ? "time-entry odd" : "time-entry even";
}

function renameCellIDs(cell, index, newIndex){
	renameProperty(cell, 'input', 'hours' + index, 'hours'+ newIndex);
	renameProperty(cell, 'input', 'ids' + index, 'ids'+ newIndex);
	// '(' is a meta special character, so it needs escaping '\'
	// since '\' is inside quotes, you need another '\'
	renameProperty(cell, 'select', index, newIndex);
	renameProperty(cell, 'a', 'javascript:deleteRow\\(' + index + '\\)',
		'javascript:deleteRow(' + newIndex+')');
	renameProperty(cell, 'a', 'javascript:showComment\\(' + index + '\\)',
		'javascript:showComment(' + newIndex+')');
}

function renameProperty(cell, tag, str, newStr){
	var j;
	var children = cell.getElementsByTagName(tag);
	for(j=0; j < children.length; j++){
		if(tag == 'input'){
			renameIDName(children[j], str, newStr);
		}else if(tag == 'a'){
			renameHref(children[j], str, newStr);
		}else if(tag == 'select'){
			renameOnChange(children[j], str, newStr);
		}
	}
}

function renameIDName(child, str, newStr){
	var id = child.id;
	var rExp = new RegExp(str);
	if(id.match(rExp)){
		child.id = id.replace( rExp, newStr);
		var name = child.name;
		child.name = name.replace( rExp, newStr);
	}
}

function renameHref(child, str, newStr){
	var href = child.href;
	var rExp = new RegExp(str);
	if(href.match(rExp)){
		child.href = href.replace( rExp, newStr);
	}
}

function renameOnChange(child, index, newIndex){
	if(child.id == 'time_entry__project_id'){
		var onchng = child.onchange;
		var row = newIndex;
		var func = function(){projectChanged(this, row);};
		//bind the row variable in the function
		func.bind(this, row);
		child.onchange = func;
	}
}

function calculateTotal(day){
	changed=true;
	var issueTable = document.getElementById("issueTable");
	var totalSpan = document.getElementById("total_hours");
	var rowCount = issueTable.rows.length;
	var dayTotal = 0.0;
	var hours, i, j, k, val, children;

	for(i=1; i < rowCount; i++){
		//There is a bug in IE7, the getElementsByName doesn't get the new elements
		//hours = document.getElementsByName("hours" + i + "[]");			
		hours = myGetElementsByName(issueTable.rows[i], "input","hours" + i + "[]");
		console.log(hours);
		//IE doesn't support trim()
		val = hours[day-1].value.replace(/^\s\s*/, '').replace(/\s\s*$/, '');			
		if( val != '' && !isNaN(val)){
			dayTotal += Number(val);
		}
	}
//	updateDayTotal(day, dayTotal);
	updateTotalTo(dayTotal);
}

//There is a bug in IE7, the getElementsByName doesn't get the new elements
//Workaround for the getElementsByName bug found in IE7
function myGetElementsByName(parent, tag, name){
	var children = parent.getElementsByTagName(tag);
	var mChildren = new Array();
	var j, k=0;
	for(j=0; j < children.length; j++){
		if(children[j].name == name){
			mChildren[k++] = children[j];
		}
	}
	return mChildren;
}
function updateDayTotal(day, dayTotal){
	var issueTable = document.getElementById("issueTable");
	var rowCount = issueTable.rows.length;
	var totalRow = issueTable.rows[rowCount-1]
	var cell = totalRow.cells[2 + day];
	var currDayTotal = Number(cell.innerHTML);
	cell.innerHTML = dayTotal;
	updateTotal(dayTotal - currDayTotal);
}

function updateTotal(increment){
	var totalSpan = document.getElementById("total_hours");
	var total = Number(totalSpan.innerHTML);
	totalSpan.innerHTML = total + increment;
}

function updateTotalTo(newTotal){
        var totalSpan = document.getElementById("total_hours");
        totalSpan.innerHTML = newTotal;
}

