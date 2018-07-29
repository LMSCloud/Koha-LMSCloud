-- На основі MARC21-структури англійською „DVDs, VHS“
-- Переклад/адаптація: Сергій Дубик, Ольга Баркова (2011)

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '090', '', 1, 'Шифри', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '090', 'a', 0, 0, 'Поличний індекс', '',                    0, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'b', 0, 0, 'Local cutter number (OCLC) ; Book number/undivided call number, CALL (RLIN)', 'Local cutter number (OCLC) ; Book number/undivided call number, CALL (RLIN)', 0, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'e', 0, 1, 'Інвентарний номер', '',                  0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'f', 0, 1, 'Сигла зберігання', '',                   0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'h', 0, 1, 'Формат', '',                             0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'i', 0, 0, 'Output transaction instruction, INS (RLIN)', 'Output transaction instruction, INS (RLIN)', 0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'l', 0, 0, 'Extra card control statement, EXT (RLIN)', 'Extra card control statement, EXT (RLIN)', 0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'n', 0, 0, 'Additional local notes, ANT (RLIN)', 'Additional local notes, ANT (RLIN)', 0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'p', 0, 0, 'Pathfinder code, PTH (RLIN)', 'Pathfinder code, PTH (RLIN)', 0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 't', 0, 0, 'Field suppresion, FSP (RLIN)', 'Field suppresion, FSP (RLIN)', 0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'v', 0, 0, 'Volumes, VOL (RLIN)', 'Volumes, VOL (RLIN)', 0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'y', 0, 0, 'Date, VOL (RLIN)', 'Date, VOL (RLIN)',   0, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '090', 'z', 0, 0, 'Retention, VOL (RLIN)', 'Retention, VOL (RLIN)', 0, 5, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '099', '', 1, 'Періодичні видання', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '099', 'a', 0, 0, 'Індекс', '',                             0, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '099', 'e', 0, 0, 'Рік', '',                                0, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '099', 'f', 0, 0, 'Кількість комплектів', '',               0, -6, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '100', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   1, 0, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '110', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   1, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '111', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   1, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '130', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   1, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '240', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   2, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '243', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   2, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '400', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   4, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '410', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   4, -6, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '411', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   4, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '440', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   4, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '600', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '610', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '611', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '630', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '650', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '651', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '690', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '691', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '696', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '697', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '698', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '699', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   6, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '700', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '710', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '711', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '730', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '789', '9', 0, 0, 9, 9,                                     7, -6, '', '', '', NULL, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '796', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '797', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '798', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '799', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   7, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '800', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '810', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '811', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '830', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '880', '9', 0, 1, 9, 9,                                     8, -6, '', '', '', NULL, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '886', '9', 0, 1, 9, 9,                                     8, -6, '', '', '', NULL, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '896', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '897', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '898', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '899', '9', 0, 0, '9 (RLIN)', '9 (RLIN)',                   8, -5, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '900', '', 1, 'Макрооб’єкти', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '900', '4', 0, 1, 'Relator code', 'Relator code',           9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', '6', 0, 0, 'Linkage', 'Linkage',                     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'a', 0, 0, 'Ім’я макрооб’єкта', '',                  9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'b', 0, 0, 'Доступ до макрооб’єкта', '',             9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'c', 0, 1, 'Titles and other words associated with a name', 'Titles and other words associated with a name', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'd', 0, 0, 'Dates associated with a name', 'Dates associated with a name', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'e', 0, 1, 'Relator term', 'Relator term',           9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'f', 0, 0, 'Date of a work', 'Date of a work',       9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'j', 0, 1, 'Attribution qualifier', 'Attribution qualifier', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'k', 0, 1, 'Form subheading', 'Form subheading',     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'n', 0, 1, 'Number of part/section of a work', 'Number of part/section of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'q', 0, 0, 'Fuller form of name', 'Fuller form of name', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 't', 0, 0, 'Title of a work', 'Title of a work',     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '900', 'u', 0, 0, 'Affiliation', 'Affiliation',             9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '901', '', 1, 'Тип документа', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '901', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 't', 0, 0, 'Тип документа', '',                      9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '901', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '902', '', 1, 'Елемент локальних даних B', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '902', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '902', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '903', '', 1, 'Елемент локальних даних C', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '903', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '903', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '904', '', 1, 'Елемент локальних даних D', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '904', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '904', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '905', '', 1, 'Елемент локальних даних E', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '905', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '905', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '906', '', 1, 'Елемент локальних даних F', 'Елемент локальних даних F', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '906', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '906', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '907', '', 1, 'Елемент локальних даних G', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '907', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '907', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '908', '', '', 'Параметр входу даних', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '908', 'a', 0, 0, 'Параметр входу даних', '',               9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '910', '', '', 'Данные о правах пользователя', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '910', 'a', 0, 0, 'Данные о правах пользователя', '',       9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '911', '', 1, 'EQUIVALENCE OR CROSS-REFERENCE-CONFERENCE OR MEETING NAME [LOCAL, CANADA]', 'EQUIVALENCE OR CROSS-REFERENCE-CONFERENCE OR MEETING NAME [LOCAL, CANADA]', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', NULL, '911', '4', 0, 1, 'Relator code', 'Relator code',         9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', '6', 0, 0, 'Linkage', 'Linkage',                   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'a', 0, 0, 'Meeting name or jurisdiction name as entry element', 'Meeting name or jurisdiction name as entry element', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'b', 0, 0, 'Number [OBSOLETE]', 'Number [OBSOLETE]', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'c', 0, 0, 'Location of meeting', 'Location of meeting', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'd', 0, 0, 'Date of meeting', 'Date of meeting',   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'e', 0, 1, 'Subordinate unit', 'Subordinate unit', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'f', 0, 0, 'Date of a work', 'Date of a work',     9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'k', 0, 1, 'Form subheading', 'Form subheading',   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'n', 0, 1, 'Number of part/section/meeting', 'Number of part/section/meeting', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'q', 0, 0, 'Name of meeting following jurisdiction name entry element', 'Name of meeting following jurisdiction name entry element', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 't', 0, 0, 'Title of a work', 'Title of a work',   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '911', 'u', 0, 0, 'Affiliation', 'Affiliation',           9, -6, NULL, NULL, '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '930', '', 1, 'Еквівалент або перехресне посилання — уніфікована назва (локальне, Канада)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', NULL, '930', '6', 0, 0, 'Linkage', 'Linkage',                   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'a', 0, 0, 'Uniform title', 'Uniform title',       9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'd', 0, 1, 'Date of treaty signing', 'Date of treaty signing', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'f', 0, 0, 'Date of a work', 'Date of a work',     9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'h', 0, 0, 'Medium', 'Medium',                     9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'k', 0, 1, 'Form subheading', 'Form subheading',   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'm', 0, 1, 'Medium of performance for music', 'Medium of performance for music', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'n', 0, 1, 'Number of part/section of a work', 'Number of part/section of a work', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'o', 0, 0, 'Arranged statement for music', 'Arranged statement for music', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 'r', 0, 0, 'Key for music', 'Key for music',       9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 's', 0, 0, 'Version', 'Version',                   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '930', 't', 0, 0, 'Title of a work', 'Title of a work',   9, -6, NULL, NULL, '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '936', '', '', 'OCLC-дані; частина, яка використовується для каталогізації', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '936', 'a', 0, 1, 'OCLC-дані; частина, яка використовується для каталогізації', '', 9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '940', '', 1, 'Еквівалент чи перехресне посилання — уніфікована назва (застаріле) (лише CAN/MARC)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '940', '6', 0, 0, 'Linkage', 'Linkage',                     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'a', 0, 0, 'Uniform title', 'Uniform title',         9, -6, '', '', '', 1, '', '', NULL),
 ('VR', '', '940', 'd', 0, 1, 'Date of treaty signing', 'Date of treaty signing', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'f', 0, 0, 'Date of a work', 'Date of a work',       9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'h', 0, 0, 'Medium', 'Medium',                       9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'k', 0, 1, 'Form subheading', 'Form subheading',     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'm', 0, 1, 'Medium of performance for music', 'Medium of performance for music', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'n', 0, 1, 'Number of part/section of a work', 'Number of part/section of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'o', 0, 0, 'Arranged statement for music', 'Arranged statement for music', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 'r', 0, 0, 'Key for music', 'Key for music',         9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '940', 's', 0, 0, 'Version', 'Version',                     9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '941', '', 1, 'Еквівалент чи перехресне посилання — ліцензована назва (застаріле) (лише CAN/MARC)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', NULL, '941', 'a', 0, 0, 'Romanized title', 'Romanized title',   9, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '941', 'h', 0, 0, 'Medium', 'Medium',                     9, -6, NULL, NULL, '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '942', '', '', 'Додаткові дані (Коха)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '942', '0', 0, 0, 'Кількість видач (випожичань) для усіх примірників', '', 9, -5, 'biblioitems.totalissues', '', '', NULL, '', '', NULL),
 ('VR', '', '942', '2', 0, 0, 'Код системи класифікації для розстановки фонду', '', 9, 0, 'biblioitems.cn_source', 'cn_source', '', NULL, '', '', NULL),
 ('VR', '', '942', '6', 0, 0, 'Нормалізована класифікація Коха для сортування', '', -1, 7, 'biblioitems.cn_sort', '', '', 0, '', '', NULL),
 ('VR', '', '942', 'a', 0, 0, 'Institution code (застаріло)', '',       9, -5, '', '', '', NULL, '', '', NULL),
 ('VR', '', '942', 'c', 1, 0, 'Тип одиниці (рівень запису)', '',        9, 0, 'biblioitems.itemtype', 'itemtypes', '', NULL, '', '', NULL),
 ('VR', '', '942', 'e', 0, 0, 'Видання /частина шифру/', '',            9, 0, NULL, '', '', NULL, '', '', NULL),
 ('VR', '', '942', 'h', 0, 0, 'Класифікаційна частина шифру збереження', '', 9, 0, 'biblioitems.cn_class', '', '', NULL, '', '', NULL),
 ('VR', '', '942', 'i', 0, 1, 'Примірникова частина шифру збереження', '', 9, 9, 'biblioitems.cn_item', '', '', NULL, '', '', NULL),
 ('VR', '', '942', 'k', 0, 0, 'Префікс шифру зберігання', '',           9, 0, 'biblioitems.cn_prefix', '', '', NULL, '', '', NULL),
 ('VR', '', '942', 'm', 0, 0, 'Суфікс шифру зберігання', '',            9, 0, 'biblioitems.cn_suffix', '', '', 0, '', '', NULL),
 ('VR', '', '942', 'n', 0, 0, 'Статус приховування в ЕК', '',           9, 0, NULL, '', '', 0, '', '', NULL),
 ('VR', '', '942', 's', 0, 0, 'Позначка про запис серіального видання', 'Запис серіального видання', 9, -5, 'biblio.serial', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '943', '', 1, 'Еквівалент чи перехресне посилання — назва колективу (застаріле) (лише CAN/MARC)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '943', '6', 0, 0, 'Linkage', 'Linkage',                     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'a', 0, 0, 'Uniform title', 'Unifor title',          9, 5, '', '', '', 1, '', 130, NULL),
 ('VR', '', '943', 'd', 0, 1, 'Date of treaty signing', 'Date of treaty signing', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'f', 0, 0, 'Date of a work', 'Date of a work',       9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'h', 0, 0, 'Medium', 'Medium',                       9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'k', 0, 1, 'Form subheading', 'Form subheading',     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'm', 0, 1, 'Medium of performance for music', 'Medium of performance for music', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'n', 0, 1, 'Number of part/section of a work', 'Number of part/section of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'o', 0, 0, 'Arranged statement for music', 'Arranged statement for music', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 'r', 0, 0, 'Key for music', 'Key for music',         9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '943', 's', 0, 0, 'Version', 'Version',                     9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '945', '', 1, 'Локальне — інформація про обробку', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '945', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '945', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '946', '', 1, 'Локальне — інформація про обробку', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '946', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '946', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '947', '', 1, 'Локальне — інформація про обробку', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '947', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '947', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '948', '', 1, 'Локальне — інформація про обробку; позначення частини серії', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '948', '0', 0, 1, '0 (OCLC)', '0 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '1', 0, 1, '1 (OCLC)', '1 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '2', 0, 1, '2 (OCLC)', '2 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '3', 0, 1, '3 (OCLC)', '3 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '4', 0, 1, '4 (OCLC)', '4 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '5', 0, 1, '5 (OCLC)', '5 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '6', 0, 1, '6 (OCLC)', '6 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '7', 0, 1, '7 (OCLC)', '7 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '8', 0, 1, '8 (OCLC)', '8 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', '9', 0, 1, '9 (OCLC)', '9 (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'a', 0, 0, 'Series part designator, SPT (RLIN)', 'Series part designator, SPT (RLIN)', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '948', 'b', 0, 1, 'b (OCLC)', 'b (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'c', 0, 1, 'c (OCLC)', 'c (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'd', 0, 1, 'd (OCLC)', 'd (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'e', 0, 1, 'e (OCLC)', 'e (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'f', 0, 1, 'f (OCLC)', 'f (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'g', 0, 1, 'g (OCLC)', 'g (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'h', 0, 1, 'h (OCLC)', 'h (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'i', 0, 1, 'i (OCLC)', 'i (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'j', 0, 1, 'j (OCLC)', 'j (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'k', 0, 1, 'k (OCLC)', 'k (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'l', 0, 1, 'l (OCLC)', 'l (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'm', 0, 1, 'm (OCLC)', 'm (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'n', 0, 1, 'n (OCLC)', 'n (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'o', 0, 1, 'o (OCLC)', 'o (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'p', 0, 1, 'p (OCLC)', 'p (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'q', 0, 1, 'q (OCLC)', 'q (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'r', 0, 1, 'r (OCLC)', 'r (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 's', 0, 1, 's (OCLC)', 's (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 't', 0, 1, 't (OCLC)', 't (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'u', 0, 1, 'u (OCLC)', 'u (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'v', 0, 1, 'v (OCLC)', 'v (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'w', 0, 1, 'w (OCLC)', 'w (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'x', 0, 1, 'x (OCLC)', 'x (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'y', 0, 1, 'y (OCLC)', 'y (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '948', 'z', 0, 1, 'z (OCLC)', 'z (OCLC)',                   9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '949', '', 1, 'Локальне — інформація про обробку', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '949', '0', 0, 1, 0, 0,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '1', 0, 1, 1, 1,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '2', 0, 1, 2, 2,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '3', 0, 1, 3, 3,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '4', 0, 1, 4, 4,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '5', 0, 1, 5, 5,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '6', 0, 1, 6, 6,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '7', 0, 1, 7, 7,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '8', 0, 1, 8, 8,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', '9', 0, 1, 9, 9,                                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'a', 0, 1, 'a', 'a',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'b', 0, 1, 'b', 'b',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'c', 0, 1, 'c', 'c',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'd', 0, 1, 'd', 'd',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'e', 0, 1, 'e', 'e',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'f', 0, 1, 'f', 'f',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'g', 0, 1, 'g', 'g',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'h', 0, 1, 'h', 'h',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'i', 0, 1, 'i', 'i',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'j', 0, 1, 'j', 'j',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'k', 0, 1, 'k', 'k',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'l', 0, 1, 'l', 'l',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'm', 0, 1, 'm', 'm',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'n', 0, 1, 'n', 'n',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'o', 0, 1, 'o', 'o',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'p', 0, 1, 'p', 'p',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'q', 0, 1, 'q', 'q',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'r', 0, 1, 'r', 'r',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 's', 0, 1, 's', 's',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 't', 0, 1, 't', 't',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'u', 0, 1, 'u', 'u',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'v', 0, 1, 'v', 'v',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'w', 0, 1, 'w', 'w',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'x', 0, 1, 'x', 'x',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'y', 0, 1, 'y', 'y',                                 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '949', 'z', 0, 1, 'z', 'z',                                 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '950', '', 1, 'Локальне зберігання', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '950', 'a', 0, 0, 'Classification number, LCAL (RLIN)', 'Classification number, LCAL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'b', 0, 0, 'Book number/undivided call number, LCAL (RLIN)', 'Book number/undivided call number, LCAL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'd', 0, 1, 'Additional free-text stamp above the call number, LCAL (RLIN)', 'Additional free-text stamp above the call number, LCAL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'e', 0, 1, 'Additional free-text or profiled stamp below the call number, LCAL (RLIN)', 'Additional free-text or profiled stamp below the call number, LCAL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'f', 0, 0, 'Location-level footnote, LFNT (RLIN)', 'Location-level footnote, LFNT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'h', 0, 0, 'Location-level output transaction history, LHST (RLIN)', 'Location-level output transaction history, LHST (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'i', 0, 0, 'Location-level extra card request, LEXT (RLIN)', 'Location-level extra card request, LEXT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'l', 0, 0, 'Permanent shelving location, LOC (RLIN)', 'Permanent shelving location, LOC (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'n', 0, 1, 'Location-level additional note, LANT (RLIN)', 'Location-level additional note, LANT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'p', 0, 0, 'Location-level pathfinder, LPTH (RLIN)', 'Location-level pathfinder, LPTH (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 't', 0, 0, 'Location-level field suppression, LFSP (RLIN)', 'Location-level field suppression, LFSP (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'u', 0, 1, 'Non-printing notes, LANT (RLIN)', 'Non-printing notes, LANT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'v', 0, 0, 'Volumes, LVOL (RLIN)', 'Volumes, LVOL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'w', 0, 0, 'Subscription status code, LANT (RLIN)', 'Subscription status code, LANT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'y', 0, 0, 'Date, LVOL (RLIN)', 'Date, LVOL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '950', 'z', 0, 0, 'Retention, LVOL (RLIN)', 'Retention, LVOL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '951', '', 1, 'Еквівалент чи перехресне посилання — географічна назва / назва області (застаріле) (лише CAN/MARC)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '951', '2', 0, 0, 'Source of heading or term', 'Source of heading or term', 6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', '3', 0, 0, 'Materials specified', 'Materials specified', 6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', '6', 0, 0, 'Linkage', 'Linkage',                     6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', 'a', 0, 0, 'Geographic name', 'Geographic name',     6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', 'b', 0, 1, 'Geographic name following place entry element [OBSOLETE]', 'Geographic name following place entry element [OBSOLETE]', 6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', 'v', 0, 1, 'Form subdivision', 'Form subdivision',   6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', 'x', 0, 1, 'General subdivision', 'General subdivision', 6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', 'y', 0, 1, 'Chronological subdivision', 'Chronological subdivision', 6, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '951', 'z', 0, 1, 'Geographic subdivision', 'Geographic subdivision', 6, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '952', '', 1, 'Дані про примірники та розташування (Koha)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '952', '0', 0, 0, 'Статус вилучення', '',                   10, 0, 'items.withdrawn', 'WITHDRAWN', '', 0, '', '', NULL),
 ('VR', '', '952', '1', 0, 0, 'Статус втрати/відсутності', '',          10, 0, 'items.itemlost', 'LOST', '', 0, '', '', NULL),
 ('VR', '', '952', '2', 0, 0, 'Джерело класифікації чи схема поличного розташування', '', 10, 0, 'items.cn_source', 'cn_source', '', NULL, '', '', NULL),
 ('VR', '', '952', '3', 0, 0, 'Нумерація (об’єднаний том чи інша частина)', '', 10, -1, 'items.materials', '', '', NULL, '', '', NULL),
 ('VR', '', '952', '4', 0, 0, 'Стан пошкодження', '',                   10, 0, 'items.damaged', 'DAMAGED', '', NULL, '', '', NULL),
 ('VR', '', '952', '5', 0, 0, 'Статус обмеження доступу', '',           10, 0, 'items.restricted', 'RESTRICTED', '', 0, '', '', NULL),
 ('VR', '', '952', '6', 0, 0, 'Нормалізована класифікація Коха для сортування', '', -1, 7, 'items.cn_sort', '', '', 0, '', '', NULL),
 ('VR', '', '952', '7', 0, 0, 'Тип обігу (не для випожичання)', '',     10, 0, 'items.notforloan', 'NOT_LOAN', '', 0, '', '', NULL),
 ('VR', '', '952', '8', 0, 0, 'Вид зібрання', '',                       10, 0, 'items.ccode', 'CCODE', '', 0, '', '', NULL),
 ('VR', '', '952', '9', 0, 0, 'Внутрішній № примірника (items.itemnumber)', 'Внутрішній № примірника', -1, 7, 'items.itemnumber', '', '', 0, '', '', NULL),
 ('VR', '', '952', 'a', 0, 1, 'Джерельне місце зберігання примірника (домашній підрозділ)', '', 10, 0, 'items.homebranch', 'branches', '', 0, '', '', NULL),
 ('VR', '', '952', 'b', 0, 1, 'Місце тимчасового зберігання чи видачі (підрозділ зберігання)', '', 10, 0, 'items.holdingbranch', 'branches', '', 0, '', '', NULL),
 ('VR', '', '952', 'c', 0, 0, 'Поличкове розташування', '',             10, 0, 'items.location', 'LOC', '', 0, '', '', NULL),
 ('VR', '', '952', 'd', 0, 0, 'Дата надходження', '',                   10, 0, 'items.dateaccessioned', '', 'dateaccessioned.pl', 0, '', '', NULL),
 ('VR', '', '952', 'e', 0, 0, 'Джерело надходження (постачальник)', '', 10, 0, 'items.booksellerid', '', '', 0, '', '', NULL),
 ('VR', '', '952', 'f', 0, 0, 'Кодований визначник розташування', '',   10, 0, 'items.coded_location_qualifier', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'g', 0, 0, 'Вартість, звичайна закупівельна ціна', '', 10, 0, 'items.price', '', '', 0, '', '', NULL),
 ('VR', '', '952', 'h', 0, 0, 'Нумерування/хронологія серіальних видань', '', 10, 0, 'items.enumchron', '', '', 0, '', '', NULL),
 ('VR', '', '952', 'i', 0, 0, 'Інвентарний номер', '',                  10, 0, 'items.stocknumber', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'j', 0, 0, 'Поличний контрольний номер', '',         10, -1, 'items.stack', 'STACK', '', NULL, '', '', NULL),
 ('VR', '', '952', 'l', 0, 0, 'Видач загалом', '',                      10, -5, 'items.issues', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'm', 0, 0, 'Продовжень загалом', '',                 10, -5, 'items.renewals', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'n', 0, 0, 'Загалом резервувань', '',                10, -5, 'items.reserves', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'o', 0, 0, 'Повний (примірниковий) шифр збереження', '', 10, 0, 'items.itemcallnumber', '', NULL, 0, '', '', NULL),
 ('VR', '', '952', 'p', 0, 0, 'Штрих-код', '',                          10, 0, 'items.barcode', '', 'barcode.pl', 0, '', '', NULL),
 ('VR', '', '952', 'q', 0, 0, 'Дата завершення терміну випожичання', '', 10, -5, 'items.onloan', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'r', 0, 0, 'Дата, коли останній раз бачено примірник', '', 10, -5, 'items.datelastseen', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 's', 0, 0, 'Дата останнього випожичання чи повернення', '', 10, -5, 'items.datelastborrowed', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 't', 0, 0, 'Порядковий номер комплекту/примірника', '', 10, 0, 'items.copynumber', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'u', 0, 0, 'Уніфікований ідентифікатор ресурсів', '', 10, 0, 'items.uri', '', '', 1, '', '', NULL),
 ('VR', '', '952', 'v', 0, 0, 'Вартість, ціна заміни', '',              10, 0, 'items.replacementprice', '', '', 0, '', '', NULL),
 ('VR', '', '952', 'w', 0, 0, 'Дата, для якої чинна ціна заміни', '',   10, 0, 'items.replacementpricedate', '', '', 0, '', '', NULL),
 ('VR', '', '952', 'x', 0, 0, 'Службова (незагальнодоступна) примітка', '', 10, 1, '', '', '', NULL, '', '', NULL),
 ('VR', '', '952', 'y', 0, 0, 'Тип одиниці (рівень примірника)', '',    10, 0, 'items.itype', 'itemtypes', '', NULL, '', '', NULL),
 ('VR', '', '952', 'z', 0, 0, 'Загальнодоступна примітка щодо примірника', '', 10, 0, 'items.itemnotes', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '955', '', 1, 'Информація рівня копії', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '955', 'a', 0, 0, 'Classification number, CCAL (RLIN)', 'Classification number, CCAL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 'b', 0, 0, 'Book number/undivided call number, CCAL (RLIN)', 'Book number/undivided call number, CCAL (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 'c', 0, 0, 'Copy information and material description, CCAL + MDES (RLIN)', 'Copy information and material description, CCAL + MDES (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 'h', 0, 0, 'Copy status--for earlier dates, CST (RLIN)', 'Copy status--for earlier dates, CST (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 'i', 0, 0, 'Copy status, CST (RLIN)', 'Copy status, CST (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 'l', 0, 0, 'Permanent shelving location, LOC (RLIN)', 'Permanent shelving location, LOC (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 'q', 0, 1, 'Aquisitions control number, HNT (RLIN)', 'Aquisitions control number, HNT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 'r', 0, 0, 'Circulation control number, HNT (RLIN)', 'Circulation control number, HNT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '955', 's', 0, 1, 'Shelflist note, HNT (RLIN)', 'Shelflist note, HNT (RLIN)', 9, 5, '', '', '', 1, '', '', NULL),
 ('VR', '', '955', 'u', 0, 1, 'Non-printing notes, HNT (RLIN)', 'Non-printing notes, HNT (RLIN)', 9, 5, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '956', '', 1, 'Локальне — електронне місцезнаходження та доступ', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '956', '2', 0, 0, 'Access method', 'Access method',         9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', '3', 0, 0, 'Materials specified', 'Materials specified', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', '6', 0, 0, 'Linkage', 'Linkage',                     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'a', 0, 1, 'Host name', 'Host name',                 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'b', 0, 1, 'Access number', 'Access number',         9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'c', 0, 1, 'Compression information', 'Compression information', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'd', 0, 1, 'Path', 'Path',                           9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'f', 0, 1, 'Electronic name', 'Electronic name',     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'h', 0, 0, 'Processor of request', 'Processor of request', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'i', 0, 1, 'Instruction', 'Instruction',             9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'j', 0, 0, 'Bits per second', 'Bits per second',     9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'k', 0, 0, 'Password', 'Password',                   9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'l', 0, 0, 'Logon', 'Logon',                         9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'm', 0, 1, 'Contact for access assistance', 'Contact for access assistance', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'n', 0, 0, 'Name of location of host in subfield', 'Name of location of host in subfield', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'o', 0, 0, 'Operating system', 'Operating system',   9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'p', 0, 0, 'Port', 'Port',                           9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'q', 0, 0, 'Electronic format type', 'Electronic format type', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'r', 0, 0, 'Settings', 'Settings',                   9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 's', 0, 1, 'File size', 'File size',                 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 't', 0, 1, 'Terminal emulation', 'Terminal emulation', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'u', 0, 1, 'Uniform Resource Identifier', 'Uniform Resource Identifier', 9, -6, '', '', '', 1, '', '', NULL),
 ('VR', '', '956', 'v', 0, 1, 'Hours access method available', 'Hours access method available', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'w', 0, 1, 'Record control number', 'Record control number', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'x', 0, 1, 'Nonpublic note', 'Nonpublic note',       9, 6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'y', 0, 1, 'Link text', 'Link text',                 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '956', 'z', 0, 1, 'Public note', 'Public note',             9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '960', '', 1, 'Фізичне місцезнаходження', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '960', '3', 0, 0, 'Materials specified, MATL', 'Materials specified, MATL', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '960', 'a', 0, 0, 'Фізичне місцезнаходження', '',           9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '967', '', 1, 'Додаткові ESTC-коди', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '967', 'a', 0, 0, 'GNR (RLIN)', 'GNR (RLIN)',               9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '967', 'c', 0, 0, 'PSI (RLIN)', 'PSI (RLIN)',               9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '980', '', 1, 'Еквівалент або перехресне посилання — відомості про серію — ім’я особи / назва (локальне, Канада)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '980', '4', 0, 1, 'Relator code', 'Relator code',           9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', '6', 0, 0, 'Linkage', 'Linkage',                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'a', 0, 0, 'Personal name', 'Personal name',         9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'b', 0, 0, 'Numeration', 'Numeration',               9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'c', 0, 1, 'Titles and other words associated with a name', 'Titles and other words associated with a name', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'd', 0, 0, 'Dates associated with a name', 'Dates associated with a name', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'e', 0, 1, 'Relator term', 'Relator term',           9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'f', 0, 0, 'Date of a work', 'Date of a work',       9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'h', 0, 0, 'Medium', 'Medium',                       9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'j', 0, 1, 'Attribution qualifier', 'Attribution qualifier', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'k', 0, 1, 'Form subheading', 'Form subheading',     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'm', 0, 1, 'Medium of performance for music', 'Medium of performance for music', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'n', 0, 1, 'Number of part/section of a work', 'Number of part/section of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'o', 0, 0, 'Arranged statement for music', 'Arranged statement for music', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'q', 0, 0, 'Fuller form of name', 'Fuller form of name', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'r', 0, 0, 'Key for music', 'Key for music',         9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 's', 0, 0, 'Version', 'Version',                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 't', 0, 0, 'Title of a work', 'Title of a work',     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'u', 0, 0, 'Affiliation', 'Affiliation',             9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '980', 'v', 0, 0, 'Volume/sequential designation', 'Volume/sequential designation', 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '981', '', 1, 'Еквівалент або перехресне посилання — відомості про серію — наймення організації / назва (локальне, Канада)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '981', '4', 0, 1, 'Relator code', 'Relator code',           9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', '6', 0, 0, 'Linkage', 'Linkage',                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'a', 0, 0, 'Corporate name or jurisdiction name as entry element', 'Corporate name or jurisdiction name as entry element', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'b', 0, 1, 'Subordinate unit', 'Subordinate unit',   9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'c', 0, 0, 'Location of meeting', 'Location of meeting', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'd', 0, 1, 'Date of meeting or treaty signing', 'Date of meeting or treaty signing', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'e', 0, 1, 'Relator term', 'Relator term',           9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'f', 0, 0, 'Date of a work', 'Date of a work',       9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'h', 0, 0, 'Medium', 'Medium',                       9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'k', 0, 1, 'Form subheading', 'Form subheading',     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'm', 0, 1, 'Medium of performance for music', 'Medium of performance for music', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'n', 0, 1, 'Number of part/section/meeting', 'Number of part/section/meeting', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'o', 0, 0, 'Arranged statement for music', 'Arranged statement for music', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'r', 0, 0, 'Key for music', 'Key for music',         9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 's', 0, 0, 'Version', 'Version',                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 't', 0, 0, 'Title of a work', 'Title of a work',     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'u', 0, 0, 'Affiliation', 'Affiliation',             9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '981', 'v', 0, 0, 'Volume/sequential designation', 'Volume/sequential designation', 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '982', '', 1, 'Еквівалент або перехресне посилання — відомості про серію — наймення організації / назва (локальное, Канада)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', NULL, '982', '4', 0, 1, 'Relator code', 'Relator code',         8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', '6', 0, 0, 'Linkage', 'Linkage',                   8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'a', 0, 0, 'Meeting name or jurisdiction name as entry element', 'Meeting name or jurisdiction name as entry element', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'b', 0, 0, 'Number (BK CF MP MU SE VM MX) [OBSOLETE]', 'Number (BK CF MP MU SE VM MX) [OBSOLETE]', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'c', 0, 0, 'Location of meeting', 'Location of meeting', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'd', 0, 0, 'Date of meeting', 'Date of meeting',   8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'e', 0, 1, 'Subordinate unit', 'Subordinate unit', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'f', 0, 0, 'Date of a work', 'Date of a work',     8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'h', 0, 0, 'Medium', 'Medium',                     8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'k', 0, 1, 'Form subheading', 'Form subheading',   8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'l', 0, 0, 'Language of a work', 'Language of a work', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'n', 0, 1, 'Number of part/section/meeting', 'Number of part/section/meeting', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'q', 0, 0, 'Name of meeting following jurisdiction name entry element', 'Name of meeting following jurisdiction name entry element', 8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 's', 0, 0, 'Version', 'Version',                   8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 't', 0, 0, 'Title of a work', 'Title of a work',   8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'u', 0, 0, 'Affiliation', 'Affiliation',           8, -6, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '982', 'v', 0, 0, 'Volume/sequential designation', 'Volume/sequential designation', 8, -6, NULL, NULL, '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '983', '', 1, 'Еквівалент або перехресне посилання — відомості про серію — уніфікована назва (локальное, Канада)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '983', '6', 0, 0, 'Linkage', 'Linkage',                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', '8', 0, 1, 'Field link and sequence number', 'Field link and sequence number', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'a', 0, 0, 'Uniform title', 'Uniform title',         9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'd', 0, 1, 'Date of treaty signing', 'Date of treaty signing', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'f', 0, 0, 'Date of a work', 'Date of a work',       9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'g', 0, 0, 'Miscellaneous information', 'Miscellaneous information', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'h', 0, 0, 'Medium', 'Medium',                       9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'k', 0, 1, 'Form subheading', 'Form subheading',     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'l', 0, 0, 'Language of a work', 'Language of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'm', 0, 1, 'Medium of performance for music', 'Medium of performance for music', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'n', 0, 1, 'Number of part/section of a work', 'Number of part/section of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'o', 0, 0, 'Arranged statement for music', 'Arranged statement for music', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'p', 0, 1, 'Name of part/section of a work', 'Name of part/section of a work', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'r', 0, 0, 'Key for music', 'Key for music',         9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 's', 0, 0, 'Version', 'Version',                     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 't', 0, 0, 'Title of a work', 'Title of a work',     9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '983', 'v', 0, 0, 'Volume number/sequential designation', 'Volume number/sequential designation', 9, -6, '', '', '', NULL, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '984', '', 1, 'Автоматична відомість зберігання', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '984', 'a', 0, 0, 'Holding library identification number', 'Holding library identification number', 9, 5, '', '', '', NULL, '', '', NULL),
 ('VR', '', '984', 'b', 0, 1, 'Physical description codes', 'Physical description codes', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '984', 'c', 0, 0, 'Call number', 'Call number',             9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '984', 'd', 0, 0, 'Volume or other numbering', 'Volume or other numbering', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '984', 'e', 0, 0, 'Dates', 'Dates',                         9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '984', 'f', 0, 0, 'Completeness note', 'Completeness note', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '984', 'g', 0, 0, 'Referral note', 'Referral note',         9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '984', 'h', 0, 0, 'Retention note', 'Retention note',       9, 5, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '987', '', 1, 'Локальне — історія ліцензування/конверсії', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '987', 'a', 0, 0, 'Romanization/conversion identifier', 'Romanization/conversion identifier', 9, -6, '', '', '', NULL, '', '', NULL),
 ('VR', '', '987', 'b', 0, 1, 'Agency that converted, created or reviewed', 'Agency that converted, created or reviewed', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '987', 'c', 0, 0, 'Date of conversion or review', 'Date of conversion or review', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '987', 'd', 0, 0, 'Status code', 'Status code',             9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '987', 'e', 0, 0, 'Version of conversion program used', 'Version of conversion program used', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '987', 'f', 0, 0, 'Note', 'Note',                           9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '990', '', 1, 'Дані про замовлення', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '990', 'a', 0, 1, 'Автор замовлення', '',                   9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '990', 'b', 0, 1, 'Замовлено', '',                          9, -6, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '995', '', 1, 'Рекомендація 995 (локальне, UNIMARC Франція та ін.)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '995', '0', 0, 0, 'Withdrawn status [LOCAL, KOHA]', 'Withdrawn status [LOCAL, KOHA]', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', '1', 0, 0, 'Lost status [LOCAL, KOHA]', 'Lost status [LOCAL, KOHA]', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', '2', 0, 0, 'System code (specific classification or other scheme and edition) [LOCAL, KOHA]', 'System code (specific classification or other scheme and edition) [LOCAL, KOHA]', 9, 5, '', '', '', NULL, '', '', NULL),
 ('VR', '', '995', '3', 0, 0, 'Use restrictions [LOCAL, KOHA]', 'Use restrictions [LOCAL, KOHA]', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', '4', 0, 0, 'Koha normalized classification for sorting [LOCAL, KOHA]', 'Koha normalized classification for sorting [LOCAL, KOHA]', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', '5', 0, 1, 'Coded location qualifier [LOCAL, KOHA]', 'Coded location qualifier [LOCAL, KOHA]', 9, 5, '', '', '', NULL, '', '', NULL),
 ('VR', '', '995', '6', 0, 0, 'Copy number [LOCAL, KOHA]', 'Copy number [LOCAL, KOHA]', 9, 5, '', '', '', NULL, '', '', NULL),
 ('VR', '', '995', '7', 0, 1, 'Uniform Resource Identifier [LOCAL, KOHA]', 'Uniform Resource Identifier [LOCAL, KOHA]', 9, 5, '', '', '', 1, '', '', NULL),
 ('VR', '', '995', '8', 0, 0, 'Koha collection [LOCAL, KOHA]', 'Koha collection [LOCAL, KOHA]', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', '9', 0, 0, 'Internal item number (Koha itemnumber, autogenerated) [LOCAL, KOHA]', 'Internal itemnumber (Koha itemnumber) [LOCAL, KOHA]', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'a', 0, 0, 'Origin of the item (home branch) (free text)', 'Origin of item (home branch) (free text)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'b', 0, 0, 'Origin of item (home branch) (coded)', 'Origin of item (home branch (coded)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'c', 0, 0, 'Lending or holding organisation (holding branch) (free text)', 'Lending or holding organisation (holding branch) (free text)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'd', 0, 0, 'Lending or holding organisation (holding branch) code', 'Lending or holding organisation (holding branch) code', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'e', 0, 0, 'Genre detail', 'Genre',                  9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'f', 0, 0, 'Штрих-код', '',                          9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'g', 0, 0, 'Barcode prefix', 'Barcode prefix',       9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'h', 0, 0, 'Barcode incrementation', 'Barcode incrementation', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'i', 0, 0, 'Barcode suffix', 'Barcode suffix',       9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'j', 0, 0, 'Section', 'Section',                     9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'k', 0, 0, 'Call number (full call number)', 'Call number (full call number)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'l', 0, 0, 'Numbering (volume or other part)', 'Numbering (bound volume or other part)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'm', 0, 0, 'Date of loan or deposit', 'Date of loan or deposit', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'n', 0, 0, 'Expiration of loan date', 'Expiration of loan date', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'o', 0, 1, 'Circulation type (not for loan)', 'Circulation type (not for loan)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'p', 0, 0, 'Serial', 'Serial',                       9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'q', 0, 0, 'Intended audience (age level)', 'Intended audience (age level)', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'r', 0, 0, 'Type of item and material', 'Type of item and material', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 's', 0, 0, 'Acquisition mode', 'Acquisition mode',   9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 't', 0, 0, 'Genre', 'Genre',                         9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'u', 0, 0, 'Copy note', 'Copy note',                 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'v', 0, 0, 'Periodical number', 'Periodical number', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'w', 0, 0, 'Recipient organisation code', 'Recipient organisation code', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'x', 0, 0, 'Recipient organisation, free text', 'Recipient organisation, free text', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'y', 0, 0, 'Recipient parent organisation code', 'Recipient parent organisation code', 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '995', 'z', 0, 0, 'Recipient parent organisation, free text', 'Recipient parent organisation, free text', 9, 5, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '998', '', 1, 'Персоналії', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', '', '998', 'b', 0, 0, 'Operators initials, OID (RLIN)', 'Operators initials, OID (RLIN)', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 'c', 0, 0, 'Catalogers initials, CIN (RLIN)', 'Catalogers initials, CIN (RLIN)', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 'd', 0, 0, 'First date, FD (RLIN)', 'First Date, FD (RLIN)', 9, -6, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 'i', 0, 0, 'RINS (RLIN)', 'RINS (RLIN)',             9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 'l', 0, 0, 'LI (RLIN)', 'LI (RLIN)',                 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 'n', 0, 0, 'NUC (RLIN)', 'NUC (RLIN)',               9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 'p', 0, 0, 'PROC (RLIN)', 'PROC (RLIN)',             9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 's', 0, 0, 'CC (RLIN)', 'CC (RLIN)',                 9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 't', 0, 0, 'RTYP (RLIN)', 'RTYP (RLIN)',             9, 5, '', '', '', 0, '', '', NULL),
 ('VR', '', '998', 'w', 0, 0, 'PLINK (RLIN)', 'PLINK (RLIN)',           9, 5, '', '', '', 0, '', '', NULL);

INSERT INTO marc_tag_structure  (frameworkcode, tagfield, mandatory, repeatable, liblibrarian, libopac, authorised_value) VALUES
 ('VR', '999', '', 1, 'Системні контрольні номери (Коха)', '', '');
INSERT INTO  marc_subfield_structure (frameworkcode, authtypecode, tagfield, tagsubfield, mandatory, repeatable, liblibrarian, libopac, tab, hidden, kohafield, authorised_value, value_builder, isurl, seealso, link, defaultvalue) VALUES
 ('VR', NULL, '999', 'a', 0, 0, 'Тип одиниці зберігання (застаріле)', '', -1, -5, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '999', 'b', 0, 0, 'Підклас Д’юї (Коха, застаріле)', '',   0, -5, NULL, NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '999', 'c', 0, 0, '„biblionumber“ (Коха)', '',            -1, -5, 'biblio.biblionumber', NULL, '', NULL, '', '', NULL),
 ('VR', NULL, '999', 'd', 0, 0, '„biblioitemnumber“ (Коха)', '',        -1, -5, 'biblioitems.biblioitemnumber', NULL, '', NULL, '', '', NULL);
