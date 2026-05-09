% save_fig.m
%
% Standardized figure export for Lab06. Writes a vector PDF into
% outputs/figures/<name>.pdf relative to the project root.
%
function save_fig(fh, name)
    here = fileparts(mfilename('fullpath'));
    out_dir = fullfile(here, '..', 'outputs', 'figures');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    out = fullfile(out_dir, [name '.pdf']);
    set(fh, 'Color', 'w');
    exportgraphics(fh, out, 'ContentType', 'vector');
end
